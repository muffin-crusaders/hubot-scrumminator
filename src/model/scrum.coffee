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
        # stores answers + other info for scrum
        that._scrumLog = {}
        # flag for activity during scrum
        that._recentMessage = true

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)

        # Request to get list of rooms the bot is in
        # Find the id by matching room names
        # The id is needed for the other API calls
        # ------------ start of request ----------------
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
                    # match url to room name
                    if entry.url == '/' + that._room
                        that._roomId = entry.id
                )
            )

        req.on('error', (e) ->
            that._robot.send e )

        req.end()
        # -------------- end of request ----------------

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

        # Add some extra info to the scrum log so its more identifiable
        that._scrumLog['Room'] = that._room
        now = new Date()
        day = now.getDate()
        month = now.getMonth() + 1
        year = now.getFullYear()
        hour = now.getHours()
        minutes = now.getMinutes()
        that._scrumLog['Timestamp'] = day.toString() + '/' + month.toString() + '/' + year.toString() + ' at ' +
            hour.toString() + ':' + minutes.toString()

        # Request to stream chat messages from the scrum's room
        # ------------ start of request ----------------
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
                            # reasoning is that if JSON parse fails we don't have the whole object
                            JSON.parse output
                        catch
                            console.log '... waiting on rest of response ...'
                            return
                        # handle the message
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
        # -------------- end of request ----------------

        # Request to get list of users in the scrum's room
        # ------------ start of request ----------------
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
                    # Build a section in the scrum log for everyone but the bot
                    if user.username != process.env.HUBOT_NAME && user.displayName != process.env.HUBOT_NAME
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
        # -------------- end of request ----------------

        parseLog = (response) ->
            # ignore heartbeat message
            if (response == ' \n')
                return
            # split up lines in message since most users will paste all of their answers together
            data = JSON.parse(response.toString())
            messages = data.text.split('\n')
            # get user info
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^([0-9])[\.\-](.+)$/i

            for message in messages
                # match answer, plus overly cautious checking to make sure the bot isn't trying to infiltrate
                if userid != process.env.HUBOT_NAME && displayname != process.env.HUBOT_NAME && message.match answerPattern
                    that._recentMessage = true
                    num = answerPattern.exec(message)[1]
                    that._scrumLog[userid].answers[num-1] = message
                    # Check to see if all answers have been given by the user, thank them if they have
                    if that._scrumLog[userid].answers.indexOf('') < 0
                        that._robot.send
                            room: that._room,
                            'Thanks ' + displayname.split(' ')[0]

        activityCheck = () ->
            if !that._recentMessage
                that.checkCronJob.stop()
                # end the message stream
                if reqSocket then reqSocket.end()
                # save scrum to the brain, everything before the comma is the key
                that._robot.brain.set "scrumlog" + day.toString() + month.toString() + year.toString() + hour.toString() + minutes.toString(), that._scrumLog
                that._robot.brain.save
                that._recentMessage = true
            that._recentMessage = false

        # Run activityCheck every 15 minutes
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
