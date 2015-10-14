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


module.exports = (robot) ->
    robot.respond /schedule scrum at `?(.+?)`? in (\S+)/i, (res) ->
        cron = res.match[1]
        room = res.match[2]
        scrum = createScrum robot, cron, room

        res.reply 'Scheduled scrum ' + scrum.toPrintable()

    robot.respond /list scrums/i, (res) ->
        message = ''
        message += scrum_list.indexOf(scrum) + ': ' + scrum.toPrintable() + '\n' for scrum in scrum_list
        if message == '' then message = 'No scrums scheduled'
        res.send message

    robot.respond /delete scrum (.+)/i, (res) ->
        index = parseInt(res.match[1], 10)
        scrum = scrum_list[index]
        storedScrums = robot.brain.data._private.scrumminator.scrums
        scrum.stopCronJob()
        # removes the chosen scrum from the list
        scrum_list.splice(scrum_list.indexOf(scrum), 1)
        for storedScrum in storedScrums
            if scrum.getId() == storedScrum.id
                # remove from brain
                storedScrums.splice(storedScrums.indexOf(storedScrum), 1)
                robot.brain.save
                res.send "Scrum " + index + " has been canceled"
                return

    robot.respond /stop scrum (.+)/i, (res) ->
        id = parseInt(res.match[1], 10)
        scrum = scrum_list[id]
        scrum.stopCronJob()
        storedScrums = robot.brain.data._private.scrumminator.scrums
        for storedScrum in storedScrums
            if scrum.getId() == storedScrum.id
                storedScrum.active = false
                robot.brain.save()
                res.send "Stopped scrum"

    robot.respond /start scrum (.+)/i, (res) ->
        id = parseInt(res.match[1], 10)
        scrum = scrum_list[id]
        scrum.startCronJob()
        storedScrums = robot.brain.data._private.scrumminator.scrums
        for storedScrum in storedScrums
            if scrum.getId() == storedScrum.id
                storedScrum.active = true
                robot.brain.save()
                res.send "Started scrum"

    #LOAD PAST SCRUMS
    robot.brain.on 'init', ->
        if !robot.brain.data._private.scrumminator
            robot.brain.set 'scrumminator', {'scrums': [], 'logs': {}}
        stored_scrums = robot.brain.data._private.scrumminator.scrums

        for scrum in stored_scrums
            newScrum = createScrum robot, scrum.cron, scrum.room, scrum.id, false
            if !scrum.active
                newScrum.stopCronJob()


createScrum = (robot, cron, room, id = guid(), isNew = true) ->
    scrum = new Scrum robot, cron, room, id
    # save scrum to brain so that we can load it on reboot
    if isNew
        robot.brain.data._private.scrumminator.scrums.push({ 'cron': cron, 'room': room, 'active': true, 'id': id })
        robot.brain.data._private.scrumminator.logs[id] = []
        robot.brain.save
    scrum_list.push scrum

    return scrum


# Generates an rfc4122 version 4 compliant guid.
# Taken from here: http://stackoverflow.com/questions/105034/how-to-create-a-guid-uuid-in-javascript
guid = () ->
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
        r = Math.random() * 16 | 0
        if c == 'x'
            v = r
        else
            v = (r & 0x3 | 0x8)
        return v.toString(16);
    )
