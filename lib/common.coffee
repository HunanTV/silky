###
    全局配置
###
_events = require 'events'
_watch = require 'watch'
_fs = require 'fs-extra'
_path = require 'path'
require 'colors'
_ = require 'lodash'
_plugin = require './plugin'
_update = require './update'

_pageEvent = new _events.EventEmitter()
_options = null     #用户传入的配置信息

#用户的home目录
exports.homeDirectory = process.env[if process.platform is 'win32' then 'USERPROFILE' else 'HOME']

#触发页面被改变事件
exports.onPageChanged = ()->
    exports.trigger 'page:change'

#触发事件
exports.trigger = (name, arg...)-> _pageEvent.emit(name, arg)

#监听事件
exports.addListener = (event, listener)-> _pageEvent.addListener event, listener

exports.removeListener = (event, listener)-> _pageEvent.removeListener event, listener

#监控文件夹，如果发生改变，就触发页面被改变的事件
exports.watchAndTrigger = (parent, pattern)->
    exports.watch parent, pattern, exports.onPageChanged


##监控文件
#deepWatch = exports.watch = (parent, pattern, cb)->
#	_watch.watchTree parent, (f, curr, prev)->
#		return if typeof f is "object" and not (prev and curr)
#
#		#不适合监控规则的跳过
#		return if not (pattern instanceof RegExp and pattern.test(f))
#		event = 'change'
#
#		if prev is null
#			event = 'new'
#		else if curr.nlink is 0
#			event = 'delete'
#
#		cb event, f

###
#初始化watch
initWatch = ()->
  return  #暂时不做任何监控
  #监控配置文件中的文件变化
  deepWatch _path.join(_options.workbench, _options.identity, _options.env)

  #监控文件
  for key, pattern of _config.watch
      dir = _path.join(_options.workbench, key)

      deepWatch dir, pattern, (event, file)->
          extname = _path.extname file
          triggerType = 'html'
          if extname in ['.less', '.css']
              triggerType = 'css'
          else if extname in ['.js', '.coffee']
              triggerType = 'js'

          _pageEvent.emit 'file:change:' + triggerType, event, file
          console.log "#{event} - #{file}".green
          #同时引发页面内容被改变的事件
          exports.onPageChanged()
###

#判断是否为产品环境
exports.isProduction = ()-> _options.env is 'production'

#如果是产品环境，则报错，否则返回字符
exports.combError = (error)->
    #如果是产品环境，则直接抛出错误退出
    if this.isProduction()
        console.log 'Error:'.red
        console.log error
        process.exit 1
        return

    error

#替换扩展名为指定的扩展名
exports.replaceExt = (file, ext)->
    #取文件夹再加上扩展名，不能使用path.join
    file.replace _path.extname(file), ext

#读取文件
exports.readFile = (file)-> _fs.readFileSync file, 'utf-8'

#保存文件
exports.writeFile = (file, content)-> _fs.outputFileSync file, content

exports.getTemplateDir = ()->
  _path.join _options.workbench, 'template'

#初始化
exports.init = (options)->
    _options =
        env: 'development'
        workbench: null
        buildMode: false

    _.extend _options, options
    _options.version = require('../package.json').version
    _options.identity = '.silky'

    #如果在workbench中没有找到.silky的文件夹，则将目录置为silky的samples目录
    if not _options.workbench or not _fs.existsSync _path.join(_options.workbench, _options.identity)
        _options.workbench = _path.join __dirname, '..', 'samples'

    globalConfig = {}
    localConfig = {}
    #读取配置文件
    configFileName = 'config.js'
    #读取全局配置文件
    globalConfigFile = _path.join exports.homeDirectory, _options.identity, configFileName
    globalConfig = require(globalConfigFile) if _fs.existsSync globalConfigFile

    #配置文件
    localConfigFile = _path.join _options.workbench, _options.identity, configFileName
    localConfig = require(localConfigFile) if _fs.existsSync localConfigFile

    #用本地配置覆盖全局配置
    exports.config = _.extend globalConfig, localConfig
    exports.options = _options

    #检查配置文件是否需要升级
    _update.checkConfig()
#    initWatch()
    _plugin.init()      #初始化插件

#输入当前正在操作的文件
exports.fileLog = (file, log)->
    file = _path.relative _options.workbench, file
    #console.log "#{log || " "}>#{file}"

#替换掉slash，所有奇怪的字符
exports.replaceSlash = (file)->
    file.replace(/\W/ig, "_")

#x.y.x这样的文本式路径，从data中找出对应的值
exports.xPathMapValue = (xPath, data)->
  value = data
  xPath.split('.').forEach (key)->
    return if not (value = value[key])
  value

#简单的匹配，支持绝对匹配，正则匹配，以及匿名函数匹配
exports.simpleMatch = (rules, value)->
  return false if not rules
  rules = [rules] if not (rules instanceof Array)
  result = false
  for rule in rules
    if rule instanceof RegExp   #正则匹配
      result = rule.test(value)
    else if typeof rule is 'function'
      result = rule(value)
    else
      result = rule is value

    return result if result

  false

exports.debug = (message)->

  return if not _options.debug
  console.log message