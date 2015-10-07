# Description
#   Automated scrums on gitter
#
# Commands:
#   hubot schedule scrum at (cron) in (room)- Schedules a scrum as a CronJob
#   hubot schedule scrum every (weekday|day|hour|minute) at (time) in (room) - Schedules scrum
#   hubot list scrums - lists all scrums currently scheduled
#   hubot cancel scrum (id) - cancels scrum corresponding to id
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Aleksuei Riabtsev <aleksuei.riabtsev@ec.gc.ca>

# Models
Scrum = require('./model/scrum')

scrum_list = []
id_count = 1

module.exports = (robot) ->
    robot.respond /schedule scrum at `?(.+)`? in (\S+)/i, (res) ->
        cron = res.match[1]
        room = res.match[2]
        scrum = createScrum robot, cron, room

        res.reply 'Scheduled scrum ' + scrum.toPrintable()

    # Is this useful?
    robot.respond /schedule scrum every (\S+) at (\S+) in (\S+)/i, (res) ->
        interval = res.match[1]
        time = res.match[2].split(":")
        if !time[1]
            time[1] = "00"
        room = res.match[3]

        switch interval
            when /weekday/i
                cron = '00 ' + time[1] + ' ' + time[0] + ' * * 1-5'
            when /day/i
                cron = '00 ' + time[1] + ' ' + time[0] + ' * * *'
            when /hour/i
                cron = time[1] + time[0] + ' * * * *'
            when /minute/i
                cron = time[0] + ' * * * * *'
            else
                res.reply "Sorry, I couldn't understand the time"
                return

        scrum = createScrum robot, cron, room

        res.reply 'Scheduled scrum ' + scrum.toPrintable()

    robot.respond /list scrums/i, (res) ->
        message = ''
        message += scrum.toPrintable() + '\n' for scrum in scrum_list
        res.send message

    robot.respond /cancel scrum (.+)/i, (res) ->
        id = parseInt(res.match[1], 10)
        for scrum in scrum_list
            if scrum.getId() == id
                scrum.cancelCronJob()
                # removes the chosen scrum from the list
                scrum_list.splice(scrum_list.indexOf(scrum), 1)
                robot.brain.remove 'scrum' + id
                robot.brain.save
                res.send "Scrum " + id + " has been canceled"
                return

    robot.respond /answers for (.+) from (.+)/i, (res) ->
        userid = res.match[1]
        scrumid = parseInt(res.match[2], 10)
        log = []
        for scrum in scrum_list
            if scrum.getId() == scrumid
                log = scrum.getLog()
                message = ''
                message += '>' + answer + '\n' for answer in log[userid].answers
                res.send message
                break

    #LOAD PAST SCRUMS
    robot.brain.on 'init', ->
        stored_scrums = robot.brain.data._private

        for s in Object.keys(stored_scrums)
            scrum = stored_scrums[s]
            robot.brain.remove s
            createScrum robot, scrum.time, scrum.room

createScrum = (robot, time, room) ->
    scrum = new Scrum robot, time, room, id_count
    robot.brain.set 'scrum' + id_count.toString(), {'time': time, 'room': room}
    id_count += 1
    scrum_list.push scrum
    robot.brain.save

    return scrum
