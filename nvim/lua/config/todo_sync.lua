-- Keeps a todo.txt in step with Dropbox using nothing but curl and git.
--
-- Dropbox is canonical. Every save uploads with `update = <last rev>` so a
-- stale write is rejected; on rejection we pull, three-way merge with
-- `git merge-file`, and push the result. Unmergeable edits land in the buffer
-- as conflict markers and uploads stay blocked until they are gone.
--
-- Auth is OAuth2 PKCE (no app secret). The refresh token lives in
-- stdpath("state")/todo_sync/auth.json, mode 0600, never in the repo.
-- Nothing happens on a machine until :TodoSyncLogin has been run there.
local M = {}

local uv = vim.uv
local WARN, ERROR, INFO = vim.log.levels.WARN, vim.log.levels.ERROR, vim.log.levels.INFO

local API     = "https://api.dropboxapi.com"
local CONTENT = "https://content.dropboxapi.com"

local cfg = { path = nil, remote = "/todo.txt" }

local state_dir = vim.fn.stdpath("state") .. "/todo_sync"
local files = {
  auth = state_dir .. "/auth.json",   -- { app_key, access_token, refresh_token, expires_at }
  base = state_dir .. "/base.txt",    -- content as of last successful sync (merge base)
  meta = state_dir .. "/meta.json",   -- { rev, synced_at } of that base
}

local auth, meta
local status = {
  dirty = false,        -- a push is owed (offline, or pushed while a pull was running)
  pulling = false,
  pushing = false,
  retried = false,      -- guards the conflict → pull → push loop
  last_pull_ms = 0,
  last_sync = nil,
  last_error = nil,
}

--------------------------------------------------------------------
-- 1. Small helpers
--------------------------------------------------------------------
local function notify(msg, level)
  vim.schedule(function() vim.notify("todo-sync: " .. msg, level or INFO) end)
end

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- Atomic write; `mode` (decimal, e.g. 384 = 0600) is applied when given.
local function write_file(path, text, mode)
  local tmp = path .. ".tmp"
  local fd = assert(uv.fs_open(tmp, "w", mode or 420))
  assert(uv.fs_write(fd, text))
  uv.fs_close(fd)
  assert(uv.fs_rename(tmp, path))
  if mode then uv.fs_chmod(path, mode) end
end

local function load_json(path)
  local s = read(path)
  if not s then return nil end
  local ok, v = pcall(vim.json.decode, s)
  return ok and v or nil
end

local function save_json(path, tbl, mode)
  write_file(path, vim.json.encode(tbl), mode)
end

local function b64url(s)
  return (vim.base64.encode(s):gsub("+", "-"):gsub("/", "_"):gsub("=", ""))
end

local function random_bytes(n)
  local s = uv.random and uv.random(n)
  if s then return s end
  local t = {}
  for i = 1, n do t[i] = string.char(math.random(0, 255)) end
  return table.concat(t)
end

local function has_conflict_markers(text)
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^<<<<<<< ") or line:match("^>>>>>>> ") then return true end
  end
  return false
end

--------------------------------------------------------------------
-- 2. Buffer <-> disk
--------------------------------------------------------------------
local function buf_for_path()
  local b = vim.fn.bufnr(cfg.path)
  if b ~= -1 and vim.api.nvim_buf_is_loaded(b) then return b end
end

-- Unsaved buffer edits count as local changes, so prefer the buffer when dirty.
local function local_text()
  local b = buf_for_path()
  if b and vim.bo[b].modified then
    return table.concat(vim.api.nvim_buf_get_lines(b, 0, -1, false), "\n") .. "\n"
  end
  return read(cfg.path)
end

-- Replace disk and buffer content. `noautocmd` keeps BufWritePost from
-- firing, which would otherwise push the text we just pulled.
local function set_local(text)
  local b = buf_for_path()
  if not b then return write_file(cfg.path, text) end
  local lines = vim.split(text, "\n", { plain = true })
  if lines[#lines] == "" then table.remove(lines) end
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.api.nvim_buf_call(b, function() vim.cmd("silent noautocmd write!") end)
end

--------------------------------------------------------------------
-- 3. HTTP via curl
--------------------------------------------------------------------
-- Secrets travel on stdin as curl config lines so they never show in `ps`.
-- cb(http_code, body, err_kind, err_msg); err_kind == "network" when curl itself failed.
local function curl(opts, cb)
  local args = {
    "curl", "-sS", "-K", "-", "-X", "POST",
    "--connect-timeout", "10", "--max-time", "30",
    "-w", "\n%{http_code}",
  }
  for _, h in ipairs(opts.headers or {}) do vim.list_extend(args, { "-H", h }) end
  if opts.body_file   then vim.list_extend(args, { "--data-binary", "@" .. opts.body_file }) end
  if opts.out_file    then vim.list_extend(args, { "-o", opts.out_file }) end
  if opts.header_file then vim.list_extend(args, { "-D", opts.header_file }) end
  table.insert(args, opts.url)

  local stdin = table.concat(opts.config or {}, "\n") .. "\n"
  vim.system(args, { stdin = stdin, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        return cb(nil, nil, "network", (res.stderr or ("curl exit " .. res.code)):gsub("%s+$", ""))
      end
      local out = res.stdout or ""
      local nl = out:match(".*()\n") or 1
      local code = tonumber(out:sub(nl + 1)) or 0
      local body = out:sub(1, nl - 1)
      -- with -o, an error body went to the file instead of stdout
      if opts.out_file and code ~= 200 then body = read(opts.out_file) or "" end
      cb(code, body)
    end)
  end)
end

-- Map a Dropbox response to one of: nil (ok), auth, scope, conflict, not_found, api.
local function classify(code, body)
  if code == 200 then return nil end
  local ok, j = pcall(vim.json.decode, body or "")
  local summary = (ok and type(j) == "table" and j.error_summary) or (body or ""):sub(1, 200)
  if code == 401 then return "auth", "Dropbox rejected the token (" .. summary .. "); run :TodoSyncLogin" end
  if code == 403 and summary:find("missing_scope", 1, true) then
    return "scope", "app is missing a permission (" .. summary .. "); fix scopes in the App Console and :TodoSyncLogin"
  end
  if code == 409 and summary:find("conflict", 1, true)  then return "conflict", summary end
  if code == 409 and summary:find("not_found", 1, true) then return "not_found", summary end
  return "api", ("HTTP %d: %s"):format(code, summary)
end

--------------------------------------------------------------------
-- 4. Tokens
--------------------------------------------------------------------
local function save_auth()
  vim.fn.mkdir(state_dir, "p", 448) -- 0700
  save_json(files.auth, auth, 384)   -- 0600
end

-- cb(access_token) or cb(nil, kind, err). Refreshes when < 60 s remain.
local function ensure_token(cb)
  if auth.access_token and auth.expires_at and auth.expires_at - os.time() > 60 then
    return cb(auth.access_token)
  end
  curl({
    url = API .. "/oauth2/token",
    config = {
      'data = "grant_type=refresh_token"',
      'data-urlencode = "refresh_token=' .. auth.refresh_token .. '"',
      'data-urlencode = "client_id=' .. auth.app_key .. '"',
    },
  }, function(code, body, kind, err)
    if kind then return cb(nil, kind, err) end
    if code ~= 200 then
      return cb(nil, "auth", "Dropbox login expired or revoked; run :TodoSyncLogin (" .. (body or ""):sub(1, 120) .. ")")
    end
    local j = vim.json.decode(body)
    auth.access_token = j.access_token
    auth.expires_at = os.time() + (tonumber(j.expires_in) or 14400)
    save_auth()
    cb(auth.access_token)
  end)
end

-- Authenticated call. cb(kind, err, code, body)
local function api_call(opts, cb)
  ensure_token(function(token, kind, err)
    if not token then return cb(kind, err) end
    opts.config = { 'header = "Authorization: Bearer ' .. token .. '"' }
    curl(opts, function(code, body, k, e)
      if k then return cb(k, e) end
      local kind2, msg = classify(code, body)
      cb(kind2, msg, code, body)
    end)
  end)
end

--------------------------------------------------------------------
-- 5. Dropbox endpoints
--------------------------------------------------------------------
-- cb(kind, err, text, rev)
local function download(cb)
  local out, hdr = vim.fn.tempname(), vim.fn.tempname()
  api_call({
    url = CONTENT .. "/2/files/download",
    headers = { "Dropbox-API-Arg: " .. vim.json.encode({ path = cfg.remote }) },
    out_file = out,
    header_file = hdr,
  }, function(kind, err)
    local text, headers = read(out), read(hdr) or ""
    os.remove(out)
    os.remove(hdr)
    if kind then return cb(kind, err) end
    local result = headers:match("[Dd]ropbox%-[Aa][Pp][Ii]%-[Rr]esult:%s*([^\r\n]+)")
    local ok, j = pcall(vim.json.decode, result or "")
    if not ok or type(j) ~= "table" or not j.rev then
      return cb("api", "download succeeded but no rev in Dropbox-API-Result header")
    end
    cb(nil, nil, text or "", j.rev)
  end)
end

-- mode is "add" or { [".tag"] = "update", update = rev }. cb(kind, err, rev)
local function upload(text, mode, cb)
  local tmp = vim.fn.tempname()
  write_file(tmp, text)
  api_call({
    url = CONTENT .. "/2/files/upload",
    headers = {
      "Content-Type: application/octet-stream",
      "Dropbox-API-Arg: " .. vim.json.encode({ path = cfg.remote, mode = mode, autorename = false, mute = true }),
    },
    body_file = tmp,
  }, function(kind, err, _, body)
    os.remove(tmp)
    if kind then return cb(kind, err) end
    local ok, j = pcall(vim.json.decode, body)
    if not ok or not j.rev then return cb("api", "upload succeeded but response had no rev") end
    cb(nil, nil, j.rev)
  end)
end

--------------------------------------------------------------------
-- 6. Sync
--------------------------------------------------------------------
local pull, push

local function commit_base(text, rev)
  write_file(files.base, text)
  meta = { rev = rev, synced_at = os.time() }
  save_json(files.meta, meta)
  status.last_sync = os.time()
  status.last_error = nil
end

local function fail(kind, err)
  status.last_error = err
  if kind == "network" then
    status.dirty = true
    notify("Dropbox unreachable; will retry on next save (" .. err .. ")", WARN)
  else
    notify(err, ERROR)
  end
end

local function merge(local_, base, remote, rev)
  local lf, bf, rf = vim.fn.tempname(), vim.fn.tempname(), vim.fn.tempname()
  write_file(lf, local_)
  write_file(bf, base)
  write_file(rf, remote)
  vim.system(
    { "git", "merge-file", "-p", "-L", "local", "-L", "base", "-L", "dropbox", lf, bf, rf },
    { text = true },
    function(res)
      vim.schedule(function()
        os.remove(lf); os.remove(bf); os.remove(rf)
        -- Dropbox is canonical: whatever happens, the next push's parent is the remote rev.
        commit_base(remote, rev)
        if res.code == 0 then
          set_local(res.stdout)
          notify("merged with Dropbox")
          push()
        elseif res.code < 128 then -- exit code = number of conflicts
          set_local(res.stdout)
          status.dirty = false
          notify("conflict with Dropbox — resolve the <<<<<<< markers and save", ERROR)
        else
          notify("git merge-file failed: " .. (res.stderr or ""), ERROR)
        end
      end)
    end
  )
end

-- opts.force skips the 5 s debounce (user commands, conflict recovery).
pull = function(opts)
  opts = opts or {}
  if status.pulling then return end
  if not opts.force and uv.now() - status.last_pull_ms < 5000 then
    if status.dirty then push() end
    return
  end
  status.pulling = true
  download(function(kind, err, remote, rev)
    status.pulling = false
    status.last_pull_ms = uv.now()

    if kind == "not_found" then
      local text = read(cfg.path)
      if text and #text > 0 then return push("add") end
      if not text then write_file(cfg.path, "") end
      return notify("no " .. cfg.remote .. " in Dropbox yet; it will be created on first save")
    end
    if kind then return fail(kind, err) end

    if meta and rev == meta.rev then
      if status.dirty then push() end
      return
    end

    local base = read(files.base)
    local text = local_text()
    -- No local edits (or first run): the remote copy wins outright.
    if text == nil or base == nil or text == base then
      if base == nil and text and #text > 0 and text ~= remote then
        write_file(cfg.path .. ".local-backup", text)
        notify("replaced local todo.txt with the Dropbox copy; old one saved as " .. cfg.path .. ".local-backup", WARN)
      end
      set_local(remote)
      commit_base(remote, rev)
      status.dirty = false
      return
    end
    merge(text, base, remote, rev)
  end)
end

push = function(mode)
  if status.pushing or status.pulling then
    status.dirty = true
    return
  end
  if not mode and not meta then
    status.dirty = true
    return pull({ force = true }) -- need a rev before we can update
  end
  local text = read(cfg.path)
  if not text then return end
  if has_conflict_markers(text) then
    return notify("unresolved conflict markers; not synced", WARN)
  end
  status.pushing = true
  upload(text, mode or { [".tag"] = "update", update = meta.rev }, function(kind, err, rev)
    status.pushing = false
    if kind == "conflict" and not status.retried then
      status.retried = true
      status.dirty = true
      return pull({ force = true }) -- merges, then pushes because dirty
    end
    status.retried = false
    if kind then return fail(kind, err) end
    status.dirty = false
    commit_base(text, rev)
  end)
end

--------------------------------------------------------------------
-- 7. Login (OAuth2 PKCE)
--------------------------------------------------------------------
function M.login()
  vim.ui.input({ prompt = "Dropbox app key: ", default = auth and auth.app_key or "" }, function(key)
    if not key or key == "" then return end
    local verifier = b64url(random_bytes(48))
    local digest = (vim.fn.sha256(verifier):gsub("%x%x", function(h) return string.char(tonumber(h, 16)) end))
    local url = "https://www.dropbox.com/oauth2/authorize"
      .. "?client_id=" .. key
      .. "&response_type=code"
      .. "&code_challenge=" .. b64url(digest)
      .. "&code_challenge_method=S256"
      .. "&token_access_type=offline"
    vim.ui.open(url)
    notify("approve the app in your browser, then paste the code here\n" .. url)
    vim.ui.input({ prompt = "Dropbox code: " }, function(code)
      if not code or code == "" then return end
      curl({
        url = API .. "/oauth2/token",
        config = {
          'data = "grant_type=authorization_code"',
          'data-urlencode = "code=' .. vim.trim(code) .. '"',
          'data-urlencode = "code_verifier=' .. verifier .. '"',
          'data-urlencode = "client_id=' .. key .. '"',
        },
      }, function(http, body, kind, err)
        if kind then return fail(kind, err) end
        if http ~= 200 then return notify("login failed: " .. (body or ""), ERROR) end
        local j = vim.json.decode(body)
        auth = {
          app_key = key,
          access_token = j.access_token,
          refresh_token = j.refresh_token,
          expires_at = os.time() + (tonumber(j.expires_in) or 14400),
        }
        save_auth()
        notify("logged in to Dropbox")
        M.setup(cfg)             -- now that auth exists, arm the autocmds
        pull({ force = true })
      end)
    end)
  end)
end

--------------------------------------------------------------------
-- 8. Setup, commands, autocmds
--------------------------------------------------------------------
function M.status()
  local function when(t) return t and os.date("%Y-%m-%d %H:%M:%S", t) or "—" end
  local login = "none — run :TodoSyncLogin"
  if auth then
    local left = (auth.expires_at or 0) - os.time()
    login = ("app %s…, token %s"):format(auth.app_key:sub(1, 4),
      left > 0 and ("valid " .. math.floor(left / 60) .. " min") or "expired (refreshes on next sync)")
  end
  vim.notify(table.concat({
    "todo-sync",
    "  file:      " .. tostring(cfg.path) .. "  ⇄  dropbox:" .. cfg.remote,
    "  login:     " .. login,
    "  rev:       " .. (meta and meta.rev or "never synced"),
    "  last sync: " .. when(status.last_sync or (meta and meta.synced_at)),
    "  pending:   " .. tostring(status.dirty),
    "  error:     " .. (status.last_error or "none"),
  }, "\n"))
end

function M.setup(opts)
  cfg = vim.tbl_extend("force", cfg, opts or {})
  cfg.path = vim.fn.fnamemodify(vim.fn.expand(cfg.path), ":p")

  vim.api.nvim_create_user_command("TodoSyncLogin", M.login, { desc = "Authorise Dropbox for todo.txt sync" })

  auth = load_json(files.auth)
  if not auth then return end -- inert until logged in on this machine
  meta = load_json(files.meta)

  vim.api.nvim_create_user_command("TodoSyncPull",   function() pull({ force = true }) end, { desc = "Pull todo.txt from Dropbox" })
  vim.api.nvim_create_user_command("TodoSyncPush",   function() push() end,                 { desc = "Push todo.txt to Dropbox" })
  vim.api.nvim_create_user_command("TodoSyncStatus", M.status,                              { desc = "Show todo.txt sync status" })

  local group = vim.api.nvim_create_augroup("todo-sync", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufEnter" }, {
    group = group, pattern = cfg.path,
    callback = function() pull() end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group, pattern = cfg.path,
    callback = function() push() end,
  })

  -- First run on this machine: fetch the file so <leader>t has something to open.
  if vim.fn.filereadable(cfg.path) == 0 then
    vim.schedule(function() pull({ force = true }) end)
  end
end

return M
