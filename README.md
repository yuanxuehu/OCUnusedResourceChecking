# MacOS OCUnusedResourceChecking工具类应用开发

说明：一款工具类MacOS应用(OC语言实现),自动找出Xcode工程中未使用的资源文件，提高工作效率。

开发过程简单梳理，分为三步
## 1、解析选定的工程路径，资源文件全局搜索，命令find -name *.filetype，找出文件中所有的资源名（集合：key为资源名，value为KJResourceFileInfo)

## 2、正则表达式匹配出来的代码中有用到资源名，元素类型为NSString

## 3、进行key比对，打印出所有未使用的资源名key
