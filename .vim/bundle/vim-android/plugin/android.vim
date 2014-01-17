
" {{{ Utils
function! s:fillBuffer(buf_name, text)
  let temp_o = @o
  let @o = a:text

  execute 'split ' . a:buf_name

  setlocal modifiable noreadonly
  " Delete anything that may be in the buffer
  silent %delete
  silent 0put o

  setlocal nomodifiable readonly nomodified bufhidden=delete
  let @o = temp_o
endfunction

" Parse the project.properties file to locate any test projects.
" return the directories found.
function! s:getLibDir()
  let root = s:getProjectRoot()
  let lines = readfile(root . '/project.properties')

  let ref_line_start = 'android\.library\.reference\.\d\+='

  let libraries = []
  for line in lines
    if line =~# ref_line_start
      let dir = strpart(line, matchend(line, ref_line_start))
      call add(libraries, simplify(root . '/' . dir))
    endif
  endfor

  return libraries
endfunction

" Search subdirectories for a test project. Return the test project
" root directory if found.
function! s:getTestDir()
  " We make the assumption here that if a subdirectory contains a
  " project.properties file that it is the test project for our current
  " project.
  let props = findfile('project.properties', s:getProjectRoot() . '/*')

  if props != ''
    let dir = fnamemodify(props, ':h')
    if s:isTestDirectory(dir)
      return dir
    else
      return ''
    endif
  endif

  return ''
endfunction

" Search upwards from the current working directory and find
" the highest parent directory containing a project.properties.
" We assume this is the project root directory.
function! s:getProjectRoot()
  let file = findfile('project.properties', getcwd() . '/.;')
  let dir = fnamemodify(file, ':p:h')

  while file != ''
    let file = findfile('project.properties', fnamemodify(dir, ':h') . '/.;')
    if file != ''
      let dir = fnamemodify(file, ':p:h')
    endif
  endwhile

  return dir
endfunction

function! s:isTestDirectory(directory)
  let ant_properties = findfile('ant.properties', fnamemodify(a:directory, ':p'))
  if ant_properties != ''
    let lines = readfile(ant_properties)
    for line in lines
      if line =~# '^tested\.project\.dir='
        return 1
      endif
    endfor

    return 0
  else
    return 0
  endif
endfunction

function! s:getPath(root)
  return a:root.','.a:root.'/src/**/*,'.a:root.'/res/**/*'
endfunction
" }}}
" {{{ External Commands (android, ant, etc.)
function! s:callAndroid(...)
  redir => output
    execute 'silent !android ' . join(a:000, ' ')
  redir END

  return output
endfunction

function! s:callAnt(...)
  let makeprg = &makeprg

  let &makeprg = 'ant ' . join(a:000)

  if index(a:000, '-f') == -1
    let &makeprg .= ' -f ' . s:getProjectRoot() . '/build.xml'
  endif

  let errorformat = &errorformat
  set errorformat=%A\ %#[javac]\ %f:%l:\ %m,%-Z\ %#[javac]\ %p^,%-C%.%#

  make

  let &makeprg = makeprg
  let &errorformat = errorformat
endfunction

function! s:listTargets()
  let output = s:callAndroid('list', 'targets')

  let list = split(output, "\<enter>\n")

  " The top line here is garbage.
  call remove(list, 0)
  call s:fillBuffer('temp', join(list, "\n"))
endfunction

function! s:runTests()
  let build_file = s:getTestDir() . '/build.xml'
  if build_file == ''
    echo 'Test project not found. Is it located in a subdirectory of your main project?'
    return
  endif

  call s:callAnt('debug', 'install', 'test', '-f', build_file)
endfunction
" }}}
" {{{ Navigation
function! s:gotoAndroid() abort

  let line = getline(line('.'))
  let resource_pattern = '\vR\.([^.]+)\.(\w+)'
  let start = match(line, resource_pattern)
  let end = matchend(line, resource_pattern)

  let col = col('.')
  if col > start && col <= end
    let matches = matchlist(line, resource_pattern)
    let type = matches[1]
    let name = matches[2]

    let res_dir = s:getProjectRoot() . '/res'

    let dir = finddir(type, res_dir)
    if dir == ''
      " Directory not found, let's check in values.
      let file = findfile(type . 's.xml', res_dir . '/values')

      if file != ''
        execute 'edit ' . file
        call search('\vname\=("|'')' . name . '("|'')[^>]*\>.', 'we')
      endif
    else
      let file = findfile(name . '.xml', dir)

      if file != ''
        execute 'edit ' . file
      endif
    endif

  else
    " Item doesn't appear to be a resource pass the call onto tags.
    try
      normal! 
    catch /E426/
      echohl ErrorMsg | echom v:errmsg | echohl None
    endtry
  endif

endfunction

function! s:mainFind(argLead, cmdLine, cursorPos)
  return s:find(a:argLead, a:cmdLine, a:cursorPos, s:getProjectRoot())
endfunction

function! s:testFind(argLead, cmdLine, cursorPos)
  return s:find(a:argLead, a:cmdLine, a:cursorPos, s:getTestDir())
endfunction

function! s:libFind(argLead, cmdLine, cursorPos)
  let files = []
  for dir in s:getLibDir()
    call extend(files, s:find(a:argLead, a:cmdLine, a:cursorPos, dir))
  endfor

  " Remove duplicate list entries
  call filter(files, 'count(files, v:val) < 2')

  return files
endfunction

function! s:find(argLead, cmdLine, cursorPos, root)
  let path = s:getPath(a:root)

  let ignore_exts = ['png', 'jpg', 'gif', 'ico', 'db', 'apk']

  let raw_list = split(globpath(path, a:argLead . '*'), "\n")
  let files = []
  for item in raw_list
    let extension = tolower(fnamemodify(item, ':e'))
    let file = fnamemodify(item, ':t')
    let not_ignored = index(ignore_exts, extension) == -1
    let not_listed = index(files, file) == -1

    if !isdirectory(item) && not_ignored && not_listed
      call add(files, file)
    endif
  endfor

  return files
endfunction

" Edit a file in given directory or list of directories (or subdirectory
" therein). If multiple files match the name provided the user will be
" prompted to choose which file to open.
function! s:edit(file, dir, cmd)
  let files = []

  if type(a:dir) == 3 " dir is a list
    for d in a:dir
      let path = s:getPath(d)
      call extend(files, findfile(a:file, path, -1))
    endfor
  else
    let path = s:getPath(a:dir)
    let files = findfile(a:file, path, -1)
  endif

  let length = len(files)

  if length == 0
    echo 'No file was found'
  elseif length == 1
    execute a:cmd . ' ' . files[0]
  else
    " Multiple files match. Prompt for file to use.
    let choice = inputlist(map(copy(files), 'index(files, v:val) + 1.". ".v:val'))
    if choice != ''
      execute a:cmd . ' ' . files[choice - 1]
    endif
  endif
endfunction
" }}}

command! -nargs=1 -bang -complete=customlist,s:mainFind Afind     call s:edit(<f-args>, s:getProjectRoot(), 'edit')
command! -nargs=1 -bang -complete=customlist,s:testFind Atestfind call s:edit(<f-args>, s:getTestDir(), 'edit')
command! -nargs=1 -bang -complete=customlist,s:libFind Alibfind   call s:edit(<f-args>, s:getLibDir(), 'edit')

command! -nargs=1 -bang -complete=customlist,s:mainFind AVfind     call s:edit(<f-args>, s:getProjectRoot(), 'vsplit')
command! -nargs=1 -bang -complete=customlist,s:testFind AVtestfind call s:edit(<f-args>, s:getTestDir(), 'vsplit')
command! -nargs=1 -bang -complete=customlist,s:libFind AVlibfind   call s:edit(<f-args>, s:getLibDir(), 'vsplit')

command! -nargs=1 -bang -complete=customlist,s:mainFind ASfind     call s:edit(<f-args>, s:getProjectRoot(), 'split')
command! -nargs=1 -bang -complete=customlist,s:testFind AStestfind call s:edit(<f-args>, s:getTestDir(), 'split')
command! -nargs=1 -bang -complete=customlist,s:libFind ASlibfind   call s:edit(<f-args>, s:getLibDir(), 'split')

command! -nargs=1 -bang -complete=customlist,s:mainFind ATfind     call s:edit (<f-args>, s:getProjectRoot(), 'tabedit')
command! -nargs=1 -bang -complete=customlist,s:testFind ATtestfind call s:edit (<f-args>, s:getTestDir(), 'tabedit')
command! -nargs=1 -bang -complete=customlist,s:libFind ATlibfind   call s:edit (<f-args>, s:getLibDir(), 'tabedit')

command! Adebug call s:callAnt('debug')
command! Arelease call s:callAnt('release')
command! Ainstalld call s:callAnt('installd')
command! Ainstallr call s:callAnt('installr')
command! Adebugi call s:callAnt('debug install')
command! Areleasei call s:callAnt('release install')
command! -nargs=* Aclean call s:callAnt('clean', <f-args>)
command! Atest call s:runTests()
command! Auninstall call s:callAnt('uninstall')
command! -nargs=+ Aant call s:callAnt(<f-args>)

command! Alisttargets call s:listTargets()

command! Agoto call s:gotoAndroid()
