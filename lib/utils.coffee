colors   = require 'colors/safe'

module.exports =
error: (msg) -> console.log(colors.red(msg))
warn:  (msg) -> console.log(colors.yellow(msg))
info:  (msg) -> console.log(colors.white(msg))

