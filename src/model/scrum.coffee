CronJob = require('cron').CronJob
https = require('https')

class Scrum
    token = process.env.HUBOT_GITTER2_TOKEN
    id_count = 1

    constructor: (robot, time, room, id) ->
        that = this
        that._robot = robot
        that._room = room
        that._roomId = null
        that._time = time
        that._id = id
        that._chatlog = []
        that._answers = []
        that._recentMessage = false

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)

        options =
            hostname: 'api.gitter.im',
            port:     443,
            path:     '/v1/rooms/',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}

        req = https.request(options, (res) ->
            output = ''
            res.on('data', (chunk) ->
                output += chunk.toString()
                )
            res.on('end', ->
                for entry in JSON.parse(output)
                    console.log entry
                    if entry.url == '/' + that._room
                        console.log '------- MATCHED ------------\n' + entry.id.toString()
                        that._roomId = entry.id
                )
            )

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

    startScrum = ->
        console.log '----------------------------------- startScrum ----------------------------------------------'
        that = this
        that._robot.send
            room: that._room
            """Scrum time! Please provide answers to the following:
            1. What have you done since yesterday?
            2. What are you planning to do today?
            3. Do you have any blocks
            4. Any tasks to add to the Sprint Backlog? (If applicable)
            5. Have you learned or decided anything new? (If applicable)"""

        options =
            hostname: 'stream.gitter.im',
            port:     443,
            path:     '/v1/rooms/' + that._roomId + '/chatMessages',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}


        req = https.request(options, (res) ->
            output = ''
            res.on('data', (chunk) ->
                    # ugly fix for split up chunks
                    if chunk.toString() != ' \n'
                        output += chunk.toString()
                        try
                            JSON.parse output
                        catch
                            console.log '... waiting on rest of response ...'
                            return
                        parseLog output
                )
            )

        reqSocket = null
        req.on('socket', (socket) ->
            reqSocket = socket)

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

        parseLog = (response) ->
            console.log('----------------------------------------- parseLog -----------------------------------------------------')
            console.log 'response ' + response
            if (response == ' \n')
                return
            data = JSON.parse(response.toString())
            messages = data.text.split('\n')
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^[0-9]\.(.+)$/i

            for message in messages
                if userid != 'ramp-pcar-bot'
                    that._recentMessage = true
                    that._chatlog.push message
                    console.log that._chatlog
                    that._robot.send
                        room: that._room
                        'Received ' + displayname + ': ' + message
                    if message.match answerPattern
                        if !that._answers[userid]
                            that._answers[userid] = []
                        that._answers[userid].push message
                        that._robot.send
                            room: that._room
                            'Answer pattern matched'

            activityCheck = () ->
                console.log('---------------------------------- activityCheck -------------------------------------------------')
                if !that._recentMessage
                    that.checkCronJob.stop()
                    if reqSocket then reqSocket.end()
                    now = new Date()
                    day = now.getDate()
                    month = now.getMonth() + 1
                    year = now.getFullYear()
                    console.log '-END OF SCRUM FOR ' + month + '/' + day + '/' + year + '-'
                    that._robot.send
                        room: that._room
                        '-END OF SCRUM FOR ' + month + '/' + day + '/' + year + '-'
                that._recentMessage = false

            that.checkCronJob = `new CronJob('0 * * * * *', activityCheck, null, true, null);`

    cancelCronJob: ->
        this.cronJob.stop()

    toPrintable: ->
        this._id.toString() + ": " + this._room.toString() + " at " + this._time.toString()

    getId: ->
        this._id

#   team: ->
#     new Team(@robot)
#
#   players: ->
#     @.team().players()
#
#   ##
#   # Get specific player by name
#   player: (name) ->
#     Player.find(@robot, name)
#
#   prompt: (player, message) ->
#     Player.dm(@robot, player.name, message)
#
#   demo: ->
#
#
#   # FIXME: This should take a player object
#   # and return the total points they have
#   # there are a few ways to do this:
#   #   - we just find the last scrum they participated
#   #     in copy it and add 10 points, this makes it hard
#   #     to account for bonus points earned for consecutive
#   #     days of particpating in the scrum
#   #   - we scan back and total up all their points ever, grouping
#   #     the consecutive ones and applying the appropriate bonus points
#   #     for those instances
#
#
#
#   # takes a player and a callback
#   # the callback is going to receive the score for the player
#   getScore: (player, fn) ->
#     client().zscore("scrum", player.name, (err, scoreFromRedis) ->
#       if scoreFromRedis
#         player.score = scoreFromRedis
#         fn(player)
#       else
#         console.log(
#           "getScoreError: didn't get a response got \' #{scoreFromRedis} \'\n" + "player was: #{player.name}"
#         )
#     )
#
#   # TODO: JP
#   # Fix me! maybe use promises here?
#   getScores: (players, fn) ->
#     for player in players
#       client().zscore("scrum", player.name, (err, scoreFromRedis) ->
#         if scoreFromRedis
#           player.score = scoreFromRedis
#         else
#           console.log(
#             "getScoreError: didn't get a response got \' #{scoreFromRedis} \'\n" + "player was: #{player.name}"
#           )
#       ).then(fn(players))
#
#   ##
#   # Just return a key for the current day ie 2015-4-5
#   date: ->
#     new Date().toJSON().slice(0,10)


module.exports = Scrum
