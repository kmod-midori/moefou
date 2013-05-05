exports.info = {
name:'imouto'
host:'yande.re'
freq:10
}

_ = require 'underscore'
mysql = require 'mysql'
request = require 'request'
assert = require 'assert'
invoke = require 'invoke'
async = require 'async'

e = (name,data)->
	return {type:name,data}

conn = mysql.createConnection 'mysql://root:19990906c@127.0.0.1:3306/moefou'

fetch = (page,callback)->

	invoke((data,cb)->
		request({
		url:'https://yande.re/post.json'
		qs:
			limit:30
			page:page
		},cb)
	).then((rep,cb)->
		unless rep.statusCode is 200
			cb e 'stat_code',rep.statusCode
			return
		items = null
		try
			items = JSON.parse(rep.body)
		catch err
			cb e 'json_parse',err
			return
		unless _.isArray items
			cb e 'is_not_array',items
			return


		async.map(items,(item,cb)->
			item.tags = item.tags.split /\s/g
			async.waterfall([
				(cb)->
					sql = 'SELECT `gallery_id` FROM `mp_gallery` WHERE `gallery_md5` = ?'
					conn.query(sql,[item.md5],cb)

				(result,query,cb)->
					unless result.length is 0
						cb('exists')
						return


					sql = '''
								INSERT INTO `mp_gallery`
								(`gallery_width`, `gallery_height`
								, `gallery_file_url`, `gallery_sample_url`, `gallery_preview_url`
								, `gallery_source`, `gallery_file_size`, `gallery_date`
								, `gallery_rating`, `gallery_md5`, `gallery_site`
								, `gallery_site_id`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)
								'''
					conn.query(sql,[
						item.width
						item.height
						item.file_url
						item.sample_url
						item.preview_url
						item.source
						item.file_size
						Math.round(new Date().getTime()/1000)
						item.rating
						item.md5
						'imouto'
						item.id
					],(err,r)->
						item = _.extend(item,{row:r.insertId}) if r?.insertId?
						cb(err,item)
					)

			],(err,item)->
				if err is 'exists'
					cb(false,null)
					return
				cb(err,item)
			)
		,cb)
	).then((items,cb)->
		items = _.compact items
		_tags = {}
		for item in items
			for tag in item.tags
				_tags[tag] = [] unless _tags[tag]?
				_tags[tag].push(item.row)
		tags = for key,val of _tags
			{name:key,rows:val}


		async.map(tags,(tag,cb)->
			async.waterfall([
				(cb)->
					sql = 'SELECT `tag_id` FROM `mp_tags` WHERE  `tag_eng_name` = ?'
					conn.query(sql,tag.name,cb)

				(result,q...,cb)->
					unless result.length is 0
						cb(null,{insertId:result[0].tag_id})
						return

					sql = 'INSERT INTO `mp_tags` (`tag_chn_name`,`tag_eng_name`,`tag_jpn_name`,`tag_modified`) VALUES (?,?,?,?)'
					conn.query(sql,[
						''
						tag.name
						''
						Math.round(new Date().getTime()/1000)
					],cb)

				(q,f...,cb)->
					async.map(tag.rows,(row,cb)->
						sql = '''
									INSERT INTO `mp_tags_gallery` (`tr_object_id`,`tr_object_type`,`tr_tag_id`, `tr_uid`,`tr_tag_type`)
									VALUES (?,'',?,0,1)
									'''
						conn.query(sql,[
							row
							q.insertId
						],cb)
					,cb)
			],cb)
		,cb)
	).rescue((err)->
		console.dir err

	).end(null,()->
		console.log 'End.'
		conn.end()
	)

fetch(1)
