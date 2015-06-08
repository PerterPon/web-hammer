# 栾台

```
-c CONFIG, --config CONFIG
                        Config file path for luantai.
-f FILE, --file FILE  The javascript file which you want to test. Multi 
                      file splited by ','.
-p PLUGINS, --plugins PLUGINS
                      Luantai plugin. Multi file splited by ','.
-e ENV, --env ENV     Enviroment prepare file. Multi file splited by ','.
-r RULE, --rule RULE  Rule for filter test files. Only RegExp accepted!
```

# 执行解析

+ 栾台分为两个进程, 一个stage进程, 一个phantom进程. 
 
+ stage进程处理参数信息以及加载和运行插件, phantom进程执行所有的前端单元测试逻辑.

+ phantom 进程在初始化完毕之后会打开一个空白的tab页面, 提供单元测试的环境.

+ 所有在phantom中执行的文件通过scriptloade机制加载进入phantom, 具体在插件部分有解释.

+ phantom执行结束后, 将所有测试信息返回stage进程, stage进程处理后输出给用户.

# config 配置文件

config是一个json文件, 配置单元测试信息. 假如同时使用`-c`参数和其他参数(例如:`-f`), 以`-c`参数指定的配置文件为准, 其他参数会被忽略.

```
{	
	// file, 一个数组, 里面可以是单个文件, 也可以是一个文件夹
	"file" : [
		// 一个单一的测试文件
		'/home/admin/test-project/test/test-luantai.js',
		// 一个测试文件夹, 会对里面所有的文件跑mocha, 可以配合"rule"参数使用。
		'/home/admin/test-project/test2',
	],
	// rule, 一个字符串, 用于过滤"file"中的文件, 只有符合正则的文件, 才会被mocha运行.
	// 目前仅接受正则.
	"rule" : "test.*",
	// 目前插件执行顺序已经加载顺序都和数组的顺序相同, 具体插件的使用请参考下面插件的详细信息.
	"plugins" : [
		{
			// 这个json的key, 是插件的名字, 目前插件可以在三个位置：
			// 1. 栾台内置插件, 直接使用名字即可.
			// 2. node_modules 里面的插件, 也可以直接使用名字.
			// 3. 用户自定义插件, 需要填写插件的绝对路径, e.g: {
			//       "/home/admin/test/test-plugin.coffee" : {}
			//    }
			"cube" : {
				// 资源文件目录, 默认程序执行路径下的"./res"文件夹. 可以是绝对路径, 也可以是
				// 相对路径, 相对于当前程序执行路径.
				"resDir"  : "./res",
				// 资源文件目录, 默认程序执行路径下的"./tests"文件夹. 可以是绝对路径, 也可以是
				// 相对路径, 相对于当前程序执行路径.
				"testDir" : "./test"
				// cube 的urlbase参数, 默认: "/"
				"urlBase" : "/"
			}
		}
		{
			"istanbul" : {}
		}
	],
	// 环境准备文件, 假如测试需要很多类库, 例如: jquery, ext等, 可以在这里加载进去, 在
	// 开始跑具体的单元测试之前, 这些文件都会保证加载完毕.
	// 执行逻辑和"file"参数一样, 可以是单个文件, 也可以是一个文件夹, 但是不受"rule"参数作用.
	"env" : [
		
	]
}
```

# 命令行参数解析

+ -f 同"file"参数, 多个文件之间用`,`分隔, 可以是单个文件, 也可以是文件夹

+ -p 同"plugins"参数, 多个插件之间用`,`分隔, 但是无法设定具体的参数. e.g: `-p cube,istanbul`

+ -r 同"rule"参数, 只能用正则. e.g: `-r 'test.*'`

+ -e 同"env"参数, 逻辑和`-f`参数相同, 不受`-r`参数影响.

# luantai 插件机制

栾台本身作为一个提供跑单元测试的容器, 其功能仅仅只是把单元测试跑完, 并给出结果, 所以, 其他的一些功能都通过插件实现, 例如覆盖率。
栾台提供了丰富的接口供插件使用, 具体使用方法如下: 

### 这是一个具体的插件文件:

```
class TestPlugin
	
	// options 参数的值是在config文件中设置的, 例如config文件如下：
   // {
   //   plugins : [
   //       {
   //           cube : {
   //               test : 'abcd'
   //           }
   //       }
   //   ]
   // }
   // 那么, 这里options的值就是 
   // {
   //   test : 'abcd'
   // }}
   // done参数, contructor 函数可以是一个异步的方法.
	constructor : ( options, done ) ->
	
	// 当luantai server在挂载中间件之前时会执行的方法.
	// app参数是一个connect实例, 你可以挂载自己的中间件执行逻辑.
	// done 可以是一个异步方法.
	beforeMountMiddleware : ( app, done ) ->

	// 当luantai server在将所有的中间件挂载结束之后会执行的方法.
	// app参数是一个connect实例, 你可以挂载自己的中间件执行逻辑.
	// done 可以是一个异步方法.	
	afterMountMiddleware : ( app, done ) ->
	
	// 所有在phantom中执行的测试都通过scriptloader机制加载进入phantom.
	// 具体参见后面的详细解释
	scriptLoader : ( done ) ->
		done null, ( file, done ) ->
		    done null, """
		    Cube.init( {
		        base : \"#{urlBase}\",
		        enableCss : true
		      } );
		      Cube.use( \"/__test__#{file}\", function() {
		        window.callPhantom( 'luantai.scriptload.done' );
		      } );
		    """
	
	// 插件将自己所需要的前端JS文件注入到phantom中去.
	injectJs : ( done ) ->
		done null, [
		    '/home/admin/test/test.js',
		    '/home/admin/test/test2.js',
		]
	
	// feedback反馈机制, 将phantom进程具体window对象下面的某一个属性返回.
	feedback : ( done ) ->
		done null, [ 'test1', test2 ]

// 暴露一个类
module.exports = TestPlugin
```

### scriptloader

scriptloader可以让插件选择自己应该以何种方式加载进入phantom, 默认情况下, luantai会将测试文件, 也就是"file"参数中指定的文件读入内存, 然后发送给phantom进程, 通过new Function的方式将代码文本进行执行。

```
fs.readFile file, ( err, data ) ->
	unless err
	  data = """
	  #{data}
	  ;window.callPhantom( 'luantai.scriptload.done' );
	  """
	  done null, data
```

这是默认的script loader, 通过读文件的方式, 将测试文件读入内存, 然后执行完成后, 需要调用 `window.callPhantom( 'luantai.scriptload.done' );`方法，表明文件已经加载完毕, 可以开始加载下一个文件啦.