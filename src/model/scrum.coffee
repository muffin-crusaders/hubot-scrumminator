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
        that._time = time
        that._id = id
        # stores answers + other info for scrum
        that._scrumLog = {}
        # flag for activity during scrum
        that._recentMessage = true

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)


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

        # Find current room
        gitter.rooms.join(that._room)
            .then (room) ->
                # Request to get list of users in the scrum's room
                room.subscribe()
                # Each message is given an operation to signal if its a new message, edit, "viewed by" etc.
                # 'create' is used for new messages
                room.on 'chatMessages', (message) ->
                    if message.operation == 'create'
                        parseLog message

                # Request to get list of users in the scrum's room
                room.users()
                    .then (users) ->
                        for user in users
                            # Create a section for everyone but the bot
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
            # split up lines in message since most users will paste all of their answers together
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
            console.log '--------------------- activityCheck ---------------------------'
            if !that._recentMessage
                console.log 'Ending scrum'
                that.checkCronJob.stop()
                # Unsubscribe from the rooms message stream
                gitter.rooms.join(that._room)
                    .then (room) ->
                        room.unsubscribe()
                that._robot.brain.set "scrumlog" + day.toString() + month.toString() + year.toString() + hour.toString() + minutes.toString(), that._scrumLog
                that._robot.brain.save
                that._recentMessage = true
            that._recentMessage = false
            console.log 'Continuing scrum'

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
