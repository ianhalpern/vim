" Test 'tagfunc'

source vim9.vim

func TagFunc(pat, flag, info)
  let g:tagfunc_args = [a:pat, a:flag, a:info]
  let tags = []
  for num in range(1,10)
    let tags += [{
          \ 'cmd': '2', 'name': 'nothing'.num, 'kind': 'm',
          \ 'filename': 'Xfile1', 'user_data': 'somedata'.num,
          \}]
  endfor
  return tags
endfunc

func Test_tagfunc()
  set tagfunc=TagFunc
  new Xfile1
  call setline(1, ['empty', 'one()', 'empty'])
  write

  call assert_equal({'cmd': '2', 'static': 0,
        \ 'name': 'nothing2', 'user_data': 'somedata2',
        \ 'kind': 'm', 'filename': 'Xfile1'}, taglist('.')[1])

  call settagstack(win_getid(), {'items': []})

  tag arbitrary
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata1', gettagstack().items[0].user_data)
  5tag arbitrary
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata5', gettagstack().items[1].user_data)
  pop
  tag
  call assert_equal('arbitrary', g:tagfunc_args[0])
  call assert_equal('', g:tagfunc_args[1])
  call assert_equal('somedata5', gettagstack().items[1].user_data)

  let g:tagfunc_args=[]
  execute "normal! \<c-]>"
  call assert_equal('one', g:tagfunc_args[0])
  call assert_equal('c', g:tagfunc_args[1])

  let g:tagfunc_args=[]
  execute "tag /foo$"
  call assert_equal('foo$', g:tagfunc_args[0])
  call assert_equal('r', g:tagfunc_args[1])

  set cpt=t
  let g:tagfunc_args=[]
  execute "normal! i\<c-n>\<c-y>"
  call assert_equal('\<\k\k', g:tagfunc_args[0])
  call assert_equal('cir', g:tagfunc_args[1])
  call assert_equal('nothing1', getline('.')[0:7])

  let g:tagfunc_args=[]
  execute "normal! ono\<c-n>\<c-n>\<c-y>"
  call assert_equal('\<no', g:tagfunc_args[0])
  call assert_equal('cir', g:tagfunc_args[1])
  call assert_equal('nothing2', getline('.')[0:7])

  func BadTagFunc1(...)
    return 0
  endfunc
  func BadTagFunc2(...)
    return [1]
  endfunc
  func BadTagFunc3(...)
    return [{'name': 'foo'}]
  endfunc

  for &tagfunc in ['BadTagFunc1', 'BadTagFunc2', 'BadTagFunc3']
    try
      tag nothing
      call assert_false(1, 'tag command should have failed')
    catch
      call assert_exception('E987:')
    endtry
    exe 'delf' &tagfunc
  endfor

  func NullTagFunc(...)
    return v:null
  endfunc
  set tags= tfu=NullTagFunc
  call assert_fails('tag nothing', 'E433:')
  delf NullTagFunc

  bwipe!
  set tags& tfu& cpt& 
  call delete('Xfile1')
endfunc

" Test for modifying the tag stack from a tag function and jumping to a tag
" from a tag function
func Test_tagfunc_settagstack()
  func Mytagfunc1(pat, flags, info)
    call settagstack(1, {'tagname' : 'mytag', 'from' : [0, 10, 1, 0]})
    return [{'name' : 'mytag', 'filename' : 'Xtest', 'cmd' : '1'}]
  endfunc
  set tagfunc=Mytagfunc1
  call writefile([''], 'Xtest')
  call assert_fails('tag xyz', 'E986:')

  func Mytagfunc2(pat, flags, info)
    tag test_tag
    return [{'name' : 'mytag', 'filename' : 'Xtest', 'cmd' : '1'}]
  endfunc
  set tagfunc=Mytagfunc2
  call assert_fails('tag xyz', 'E986:')

  call delete('Xtest')
  set tagfunc&
  delfunc Mytagfunc1
  delfunc Mytagfunc2
endfunc

" Script local tagfunc callback function
func s:ScriptLocalTagFunc(pat, flags, info)
  let g:ScriptLocalFuncArgs = [a:pat, a:flags, a:info]
  return v:null
endfunc

" Test for different ways of setting the 'tagfunc' option
func Test_tagfunc_callback()
  func MytagFunc1(val, pat, flags, info)
    let g:MytagFunc1_args = [a:val, a:pat, a:flags, a:info]
    return v:null
  endfunc

  " Test for using a function()
  set tagfunc=function('MytagFunc1',[10])
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a11', 'E433:')
  call assert_equal([10, 'a11', '', {}], g:MytagFunc1_args)

  " Using a funcref variable to set 'tagfunc'
  let Fn = function('MytagFunc1', [11])
  let &tagfunc = Fn
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a12', 'E433:')
  call assert_equal([11, 'a12', '', {}], g:MytagFunc1_args)

  " Using a string(funcref_variable) to set 'tagfunc'
  let Fn = function('MytagFunc1', [12])
  let &tagfunc = string(Fn)
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a12', 'E433:')
  call assert_equal([12, 'a12', '', {}], g:MytagFunc1_args)

  " Test for using a funcref()
  func MytagFunc2(pat, flags, info)
    let g:MytagFunc2_args = [a:pat, a:flags, a:info]
    return v:null
  endfunc
  set tagfunc=funcref('MytagFunc1',[13])
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a13', 'E433:')
  call assert_equal([13, 'a13', '', {}], g:MytagFunc1_args)

  " Using a funcref variable to set 'tagfunc'
  let Fn = funcref('MytagFunc1', [14])
  let &tagfunc = Fn
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a14', 'E433:')
  call assert_equal([14, 'a14', '', {}], g:MytagFunc1_args)

  " Using a string(funcref_variable) to set 'tagfunc'
  let Fn = funcref('MytagFunc1', [15])
  let &tagfunc = string(Fn)
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a14', 'E433:')
  call assert_equal([15, 'a14', '', {}], g:MytagFunc1_args)

  " Test for using a script local function
  set tagfunc=<SID>ScriptLocalTagFunc
  new | only
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a15', 'E433:')
  call assert_equal(['a15', '', {}], g:ScriptLocalFuncArgs)

  " Test for using a script local funcref variable
  let Fn = function("s:ScriptLocalTagFunc")
  let &tagfunc= Fn
  new | only
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a16', 'E433:')
  call assert_equal(['a16', '', {}], g:ScriptLocalFuncArgs)

  " Test for using a string(script local funcref variable)
  let Fn = function("s:ScriptLocalTagFunc")
  let &tagfunc= string(Fn)
  new | only
  let g:ScriptLocalFuncArgs = []
  call assert_fails('tag a16', 'E433:')
  call assert_equal(['a16', '', {}], g:ScriptLocalFuncArgs)

  " Test for using a lambda function
  set tagfunc={a,\ b,\ c\ ->\ MytagFunc1(16,\ a,\ b,\ c)}
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a17', 'E433:')
  call assert_equal([16, 'a17', '', {}], g:MytagFunc1_args)

  " Set 'tagfunc' to a lambda expression
  let &tagfunc = {a, b, c -> MytagFunc1(17, a, b, c)}
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a18', 'E433:')
  call assert_equal([17, 'a18', '', {}], g:MytagFunc1_args)

  " Set 'tagfunc' to a string(lambda expression)
  let &tagfunc = '{a, b, c -> MytagFunc1(18, a, b, c)}'
  new | only
  let g:MytagFunc1_args = []
  call assert_fails('tag a18', 'E433:')
  call assert_equal([18, 'a18', '', {}], g:MytagFunc1_args)

  " Set 'tagfunc' to a variable with a lambda expression
  let Lambda = {a, b, c -> MytagFunc1(19, a, b, c)}
  let &tagfunc = Lambda
  new | only
  let g:MytagFunc1_args = []
  call assert_fails("tag a19", "E433:")
  call assert_equal([19, 'a19', '', {}], g:MytagFunc1_args)

  " Set 'tagfunc' to a string(variable with a lambda expression)
  let Lambda = {a, b, c -> MytagFunc1(20, a, b, c)}
  let &tagfunc = string(Lambda)
  new | only
  let g:MytagFunc1_args = []
  call assert_fails("tag a19", "E433:")
  call assert_equal([20, 'a19', '', {}], g:MytagFunc1_args)

  " Test for using a lambda function with incorrect return value
  let Lambda = {s -> strlen(s)}
  let &tagfunc = string(Lambda)
  new | only
  call assert_fails("tag a20", "E987:")

  " Test for clearing the 'tagfunc' option
  set tagfunc=''
  set tagfunc&

  call assert_fails("set tagfunc=function('abc')", "E700:")
  call assert_fails("set tagfunc=funcref('abc')", "E700:")
  let &tagfunc = "{a -> 'abc'}"
  call assert_fails("echo taglist('a')", "E987:")

  " Using Vim9 lambda expression in legacy context should fail
  set tagfunc=(a,\ b,\ c)\ =>\ g:MytagFunc1(21,\ a,\ b,\ c)
  new | only
  let g:MytagFunc1_args = []
  call assert_fails("tag a17", "E117:")
  call assert_equal([], g:MytagFunc1_args)

  " set 'tagfunc' to a non-existing function
  call assert_fails("set tagfunc=function('NonExistingFunc')", 'E700:')
  call assert_fails("let &tagfunc = function('NonExistingFunc')", 'E700:')
  call assert_fails("tag axb123", 'E426:')
  bw!

  " Vim9 tests
  let lines =<< trim END
    vim9script

    # Test for using function()
    def Vim9tagFunc(val: number, pat: string, flags: string, info: dict<any>): any
      g:Vim9tagFuncArgs = [val, pat, flags, info]
      return null
    enddef
    set tagfunc=function('Vim9tagFunc',\ [60])
    new | only
    g:Vim9tagFuncArgs = []
    assert_fails('tag a10', 'E433:')
    assert_equal([60, 'a10', '', {}], g:Vim9tagFuncArgs)

    # Test for using a lambda
    &tagfunc = (a, b, c) => MytagFunc1(61, a, b, c)
    new | only
    g:MytagFunc1_args = []
    assert_fails('tag a20', 'E433:')
    assert_equal([61, 'a20', '', {}], g:MytagFunc1_args)

    # Test for using a string(lambda)
    &tagfunc = '(a, b, c) => MytagFunc1(62, a, b, c)'
    new | only
    g:MytagFunc1_args = []
    assert_fails('tag a20', 'E433:')
    assert_equal([62, 'a20', '', {}], g:MytagFunc1_args)

    # Test for using a variable with a lambda expression
    var Fn: func = (a, b, c) => MytagFunc1(63, a, b, c)
    &tagfunc = Fn
    new | only
    g:MytagFunc1_args = []
    assert_fails('tag a30', 'E433:')
    assert_equal([63, 'a30', '', {}], g:MytagFunc1_args)

    # Test for using a variable with a lambda expression
    Fn = (a, b, c) => MytagFunc1(64, a, b, c)
    &tagfunc = string(Fn)
    new | only
    g:MytagFunc1_args = []
    assert_fails('tag a30', 'E433:')
    assert_equal([64, 'a30', '', {}], g:MytagFunc1_args)
  END
  call CheckScriptSuccess(lines)

  " cleanup
  delfunc MytagFunc1
  delfunc MytagFunc2
  set tagfunc&
  %bw!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
