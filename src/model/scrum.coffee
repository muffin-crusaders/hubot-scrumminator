CronJob = require('cron').CronJob
https = require('https')
Gitter = require('node-gitter')

class Scrum
    token = process.env.HUBOT_GITTER2_TOKEN
    gitter = new Gitter(token)
    id_count = 1


    constructor: (robot, time, room, id) ->
        that = this
        that._robot = robot
        that._room = room
        that._roomId = null
        that._time = time
        that._id = id
        that._scrumLog = {}
        that._recentMessage = false

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)

        gitter.currentUser()
            .then (user) ->
                user.rooms()
                    .then (rooms) ->
                        for room in rooms
                            if room.uri == that._room
                                that._roomId = room.id


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

        gitter.rooms.find(that._roomId)
            .then (room) ->
                room.subscribe()

                room.on 'chatMessages', (message) ->
                    if message.operation == 'create'
                        parseLog message

                room.users()
                    .then (users) ->
                        for user in users
                            if user.username != process.env.HUBOT_NAME && user.displayName != process.env.HUBOT_NAME
                                that._scrumLog[user.username] = {
                                    'username': user.username,
                                    'displayName': user.displayName,
                                    'answers': ['', '', '', '', '']
                                }


        parseLog = (response) ->
            console.log '----------------------- parseLog --------------------------------'
            console.log response
            data = response.model
            messages = data.text.split('\n')
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^([0-9])\.(.+)$/i

            for message in messages
                if userid != 'ramp-pcar-bot' && message.match answerPattern
                    that._recentMessage = true
                    num = answerPattern.exec(message)[1]
                    that._scrumLog[userid].answers[num-1] = message


        activityCheck = () ->
            console.log '--------------------- activityCheck ---------------------------'
            if !that._recentMessage
                console.log 'Ending scrum'
                that.checkCronJob.stop()
                gitter.rooms.find(that._roomId)
                    .then (room) ->
                        room.unsubscribe()
                that._robot.brain.set "scrumlog" + day.toString() + month.toString() + year.toString() + hour.toString() + minutes.toString(), that._scrumLog
            that._recentMessage = false
            console.log 'Continuing scrum'

        that.checkCronJob = new CronJob('*/30 * * * * *', activityCheck, null, true, null)


    cancelCronJob: ->
        this.cronJob.stop()


    toPrintable: ->
        this._id.toString() + ": " + this._room.toString() + " at `" + this._time.toString() + "`"


    getId: ->
        this._id


    getLog: ->
        this._scrumLog


module.exports = Scrum
