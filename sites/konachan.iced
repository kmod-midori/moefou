request = require 'request'
mysql = require 'mysql'
_ = require 'underscore'
gate = require 'gate'
mohair = require 'mohair'
criterion = require 'criterion'
jomap = require 'jomap'
s = require 'searchjs'
t = require('tracer').console {format:'{{timestamp}} Konachan:<{{title}}> {{message}}'}
{make_esc} = require 'iced-error'

CONFIG = JSON.parse(require('fs').readFileSync('config.json').toString())

conn = mysql.createConnection CONFIG.mysql_dev
run = (gcb)->
    esc = make_esc gcb
    t.info 'Starting'
    await request({
        url:'http://konachan.com/post.json'
        qs:
            limit:40
            page:1
    },esc defer rep)

    return gcb new Error "##{rep.statusCode}:Request to konachan is not success." if rep.statusCode != 200

    items = []
    stats = {}

    try
        items = JSON.parse rep.body
    catch e
        return gcb new Error "Failed to parse JSON:#{e.toString()}"
    t.info 'JSON data parsed. %d objects received. Starting to build query for checking existent.',items.length
    stats.itemsReceived = items.length
    #===================Build query for index======================

    q = 'SELECT gallery_site_id FROM mp_gallery WHERE ('
    params = []
    for item in items
        q += "(#{criterion(gallery_site_id:item.id,gallery_rating:item.rating).sql()}) OR "
        params.push item.id
        params.push item.rating
    q = q[0...-4]
    q += ") AND gallery_site = 'konachan'"

    #===================Query building end=========================
    await conn.query q,params,esc defer results

    idsExist = (i.gallery_site_id for i in results)

    items = items.filter (item)->item.id not in idsExist
    t.info 'Existent checking success. %d item(s) need to insert.',items.length
    stats.itemsInserted = items.length
    return gcb null,stats if items.length is 0

    options =
        map:
            width:'gallery_width'
            height:'gallery_height'
            file_url:'gallery_file_url'
            sample_url:'gallery_sample_url'
            preview_url:'gallery_preview_url'
            source:'gallery_source'
            file_size:'gallery_file_size'
            rating:'gallery_rating'
            md5:'gallery_md5'
            id:'gallery_site_id'
    galleryTable = mohair.table 'mp_gallery'

    g = gate.create()
    for item in items
        query = galleryTable.insert(_.extend(jomap.map(item,options),
            {gallery_date:Math.round(new Date().getTime()/1000),gallery_site:'konachan'}))
        item.tags = item.tags.split /\s/g
        conn.query query.sql(),query.params(),g.latch {result:1,item:g.val(item)}

    await g.await esc defer results,g

    items = _.map results,(item)->_.extend(item.item,{row:item.result.insertId})

    _tags = {}
    for item in items
        for tag in item.tags
            _tags[tag] = [] unless _tags[tag]?
            _tags[tag].push(item.row)
    tags = for key,val of _tags
        {name:key,rows:val}


    tagTable = mohair.table 'mp_tags'
    params = []
    query = for tag in tags
        q = tagTable.select('tag_eng_name,tag_id').where tag_eng_name:tag.name
        params.push q.params()[0]
        q.sql()
    query = query.join ' UNION ALL '
    t.info 'Tag existent query starting.'
    await conn.query query,params,esc defer result
    resultNames = (r.tag_eng_name for r in result)

    already = s.matchArray tags,{name:resultNames}
    needInsert = s.matchArray tags,{_not:true,name:resultNames}
    stats.tags_affected = needInsert.length

    t.info '%d tag(s) need to insert.',needInsert.length

    already = for tag in already
        id = s.matchArray(result,tag_eng_name:tag.name)[0].tag_id
        tag.id = id
        tag


    for tag in needInsert
        q = tagTable.insert tag_chn_name:'',tag_eng_name:tag.name,
        tag_jpn_name:'',tag_modified:Math.round(new Date().getTime()/1000)
        conn.query q.sql(),q.params(),g.latch result:1,row:g.val(tag.rows)

    await g.await esc defer results

    results = _.map results,(data)->{id:data.result.insertId,rows:data.row}
    results = results.concat already

    assocTable = mohair.table 'mp_tags_gallery'
    _query = []

    for tag in results
        for row in tag.rows
            _query.push
               tr_object_id:row
               tr_object_type:''
               tr_tag_id:tag.id
               tr_uid:0
               tr_tag_type:1

    query = assocTable.insertMany _query

    t.info '%d association(s) need to insert.',_query.length

    await conn.query query.sql(),query.params(),esc defer()

    t.info 'All opreation succeed.'
    return gcb null


