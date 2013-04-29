asyncblock = require 'asyncblock'
_ = require 'underscore'
url = require 'url'
needle = require 'needle'
assert = require 'assert'
mysql = require 'mysql'

fetch = (page,cb)->
	asyncblock (flow)->
    url = url.format
      protocol:'https'
      host:'yande.re'
      pathname:'post.json'
      query:
        limit:30
        page:page


    needle.get(url,proxy:'http://127.0.0.1:8080',flow.add('nd',['rep','body']))
    data = flow.get 'nd'
    assert.equal data.rep.statusCode,200,'Image Request Error'

    conn = mysql.createConnection('mysql://root:password@127.0.0.1:3306/moefou')
    conn.connect(flow.add())
    flow.wait()
    sql = 'SELECT `gallery_id` FROM `mp_gallery` WHERE `gallery_md5` = ?'
    existent = for item in data.body
      _.extend item,{queryFuture:flow.future conn.query sql,[item.md5],flow.callback()}

    for i in existent
      console.dir(i.queryFuture.result)









fetch(1)

