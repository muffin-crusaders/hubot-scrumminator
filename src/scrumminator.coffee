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

module.exports = (robot) ->
    scrum_list = []
    id_count = 1

    robot.respond /schedule scrum at `?(.+)`? in (\S+)/i, (res) ->
        cron = res.match[1]
        room = res.match[2]
        scrum = new Scrum robot, cron, room, id_count
        id_count += 1
        scrum_list.push scrum

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

        scrum = new Scrum robot, cron, room, id_count
        id_count += 1
        scrum_list.push scrum

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
                res.send "Scrum " + id + " has been canceled"
                return
                
### BROKEN - need to access chatlog and answers from Scrum now
    robot.respond /chatlog (.+)/i, (res) ->
        robot.send room: 'AleksueiR/CyberTests', chatlog.toString()

    robot.respond /answers (.+)/i, (res) ->
        userid = res.match[1]
        robot.send room: 'AleksueiR/CyberTests', if answers[userid] then answers[userid].toString() else "No answers given"
###
