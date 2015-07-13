cronJob = require('cron').CronJob
request = require 'request'

getPrice = (coin, cb)->
  url = "https://www.btcbox.co.jp/api/v1/ticker/?coin=" + coin
  options = 
    url: url
    timeout: 2000
    headers: {"user-agent": "btc checker"}
  request options, (error, response, body) ->
    cb JSON.parse(body)

module.exports = (robot) ->
  robot.respond /btc check (btc|ltc|doge)/, (res)->
    coin = res.match[1]
    getPrice coin, (data) ->
      res.send "現在:#{data.last} 売り気配:#{data.sell} 買い気配:#{data.buy} 高値:#{data.high} 安値:#{data.low}"

  robot.respond /btc monitor (btc|ltc|doge) (last|buy|sell)(>=?|<=?)([0-9.]+)/, (res)->
    coin = res.match[1]
    type = res.match[2]
    cond = res.match[3]
    price = res.match[4]
    robot.brain.data.btc_monitor = {} if !robot.brain.data.btc_monitor
    robot.brain.data.btc_monitor[coin] = {} if !robot.brain.data.btc_monitor[coin]
    robot.brain.data.btc_monitor[coin][type] = {} if !robot.brain.data.btc_monitor[coin][type]
    robot.brain.data.btc_monitor[coin][type][cond] = price
    robot.brain.save()
    res.send "monitor set #{coin} #{type}#{cond}#{price}"

  robot.respond /btc monitor list/, (res)->
    if !robot.brain.data.btc_monitor
      res.send "not found!"
      return
    for coin, type_cond of robot.brain.data.btc_monitor
      for type, cond_price of type_cond
        for cond, price of cond_price
          res.send "#{coin} #{type}#{cond}#{price}"
    

  robot.respond /btc monitor clear/, (res)->
    robot.brain.data.btc_monitor = {}
    robot.brain.save()
    res.send "clear!"


  new cronJob '00 */3 * * * *', () =>
    for coin, type_cond of robot.brain.data.btc_monitor
      getPrice coin, (data) ->
        for type, cond_price of type_cond
          for cond, price of cond_price
            if eval("data.#{type} #{cond} #{price}")
              robot.send {room:"general"}, "#{coin} #{type}#{cond}#{price} now!"
              delete robot.brain.data.btc_monitor[coin][type][cond]
              robot.brain.save()
  , null, true, "Asia/Tokyo"
