CronJob = require('cron').CronJob
https = require('https')
Gitter = require('node-gitter')
RomanNumerals = require('roman-numerals')
phrases = require('../phrases.json')

class Scrum
    gitter = new Gitter(process.env.HUBOT_GITTER2_TOKEN)
    id_count = 1


    constructor: (robot, time, room, id) ->
        that = this
        that._robot = robot
        that._room = room
        that._time = time
        that._id = id
        this._active = true
        # stores answers + other info for scrum
        that._scrumLog = {}
        # flag for activity during scrum
        that._recentMessage = true

        that.cronJob = new CronJob(time, startScrum, null, true, null, this)


    startScrum = ->
        that = this
        console.log '[hubot-scrumminator] Starting scrum in ' + that._room
        that._robot.send
            room: that._room
            """Scrum time! Please provide answers to the following:
            1. What have you done since yesterday?
            2. What are you planning to do today?
            3. Do you have any blocks
            4. Any tasks to add to the Sprint Backlog? (If applicable)
            5. Have you learned or decided anything new? (If applicable)"""

        thanked = []
        that._timeoutHandle = setTimeout(endScrum, 900000)

        # Add some extra info to the scrum log so its more identifiable
        now = new Date()
        day = now.getDate()
        month = now.getMonth() + 1
        year = now.getFullYear()
        hour = now.getHours()
        minutes = now.getMinutes()
        that._scrumLog['timestamp'] = day.toString() + '/' + month.toString() + '/' + year.toString() + ' at ' +
            hour.toString() + ':' + minutes.toString()
        that._scrumLog['participants'] = []
        that._robot.brain.data._private.scrumminator.logs[that._id].push( that._scrumLog )

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
                                that._scrumLog.participants.push({
                                    'name': user.username,
                                    'displayName': user.displayName,
                                    'answers': ['', '', '', '', '']
                                })
                        that._robot.brain.save


        parseLog = (response) ->
            data = response.model
            # split up lines in message since most users will paste all of their answers together
            messages = data.text.split('\n')
            # get user info
            userid = data.fromUser.username
            displayname = data.fromUser.displayName

            answerPattern = /^.*?([1-5]|I{1,3}|IV|V).*?(?!_)(\w.+)/i

            for message in messages
                # match answer, plus overly cautious checking to make sure the bot isn't trying to infiltrate
                if userid != process.env.HUBOT_NAME && displayname != process.env.HUBOT_NAME && message.match answerPattern
                    console.log '[hubot-scrumminator] Received answer from ' + userid
                    if that._timeoutHandle
                        clearTimeout(that._timeoutHandle)
                        that._timeoutHandle = undefined
                    that._timeoutHandle = setTimeout(endScrum, 900000)
                    num = answerPattern.exec(message)[1]
                    if isNaN(num)
                        num = RomanNumerals.toArabic(num)
                    if 0 < num <=5
                        for user in that._scrumLog.participants
                            if user.name == userid
                                user.answers[num-1] = message
                                # Check to see if atleast answers 1-3 have been given by the user, thank them if they have
                                if user.answers.indexOf('') < 0 || user.answers.indexOf('') >= 3
                                    if thanked.indexOf(userid) < 0
                                        thanked.push(userid)
                                        reply = phrases.thanks[Math.floor(Math.random()*phrases.thanks.length)];
                                        that._robot.send
                                            room: that._room,
                                            reply.replace('[username]', displayname.split(' ')[0])
                                    that._robot.brain.save


        endScrum = () ->
            console.log '[hubot-scrumminator] Ending scrum in ' + that._room
            clearTimeout(that._timeoutHandle)
            that._timeoutHandle = undefined
            # Unsubscribe from the rooms message stream
            gitter.rooms.join(that._room)
                .then (room) ->
                    room.unsubscribe()
            that._robot.brain.save

    stopCronJob: ->
        this.cronJob.stop()
        this._active = false


    startCronJob: ->
        this.cronJob.start()
        this._active = true


    toPrintable: ->
        this._room.toString() + " at `" + this._time.toString() + "` " + (if this._active then "(active)" else "(inactive)")


    getId: ->
        this._id


module.exports = Scrum
