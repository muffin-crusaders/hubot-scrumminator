CronJob = require('cron').CronJob
https = require('https')
Client = require('ftp')

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
        that._scrumLog = {}
        that._recentMessage = true

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
                    if entry.url == '/' + that._room
                        that._roomId = entry.id
                )
            )

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

    startScrum = ->
        that = this
        that._robot.send
            room: that._room
            """Scrum time! Please provide answers to the following:
            1. What have you done since yesterday?
            2. What are you planning to do today?
            3. Do you have any blocks
            4. Any tasks to add to the Sprint Backlog? (If applicable)
            5. Have you learned or decided anything new? (If applicable)"""

        that._scrumLog['Room'] = that._room
        now = new Date()
        day = now.getDate()
        month = now.getMonth() + 1
        year = now.getFullYear()
        hour = now.getHours()
        minutes = now.getMinutes()
        that._scrumLog['Timestamp'] = day.toString() + '/' + month.toString() + '/' + year.toString() + ' at ' +
            hour.toString() + ':' + minutes.toString()

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
                        output = ''
                )
            )

        reqSocket = null
        req.on('socket', (socket) ->
            reqSocket = socket)

        req.on('error', (e) ->
            that._robot.send e )

        req.end()

        options2 =
            hostname: 'api.gitter.im',
            port:     443,
            path:     '/v1/rooms/' + that._roomId + '/users',
            method:   'GET',
            headers:  {'Authorization': 'Bearer ' + token}

        req2 = https.request(options2, (res) ->
            output = ''
            res.on('data', (chunk) ->
                output += chunk.toString()
                )
            res.on('end', ->
                for user in JSON.parse(output)
                    if user.username != process.env.HUBOT_NAME
                        that._scrumLog[user.username] = {
                            'username': user.username,
                            'displayName': user.displayName,
                            'answers': ['', '', '', '', '']
                        }
                )
            )
        req2.on('error', (e) ->
            that._robot.send e )

        req2.end()

        parseLog = (response) ->
            if (response == ' \n')
                return
            data = JSON.parse(response.toString())
            messages = data.text.split('\n')
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^([0-9])[\.\-](.+)$/i

            for message in messages
                if userid != process.env.HUBOT_NAME && displayname != process.env.HUBOT_NAME && message.match answerPattern
                    that._recentMessage = true
                    num = answerPattern.exec(message)[1]
                    that._scrumLog[userid].answers[num-1] = message

        activityCheck = () ->
            if !that._recentMessage
                that.checkCronJob.stop()
                if reqSocket then reqSocket.end()
                console.log that._scrumLog
                that._robot.brain.set "scrumlog" + day.toString() + month.toString() + year.toString() + hour.toString() + minutes.toString(), that._scrumLog
                that._recentMessage = true
            that._recentMessage = false

        that.checkCronJob = new CronJob('0 */15 * * * *', activityCheck, null, true, null)

    cancelCronJob: ->
        this.cronJob.stop()

    toPrintable: ->
        this._id.toString() + ": " + this._room.toString() + " at `" + this._time.toString() + "`"

    getId: ->
        this._id

    getLog: ->
        this._scrumLog


module.exports = Scrum
