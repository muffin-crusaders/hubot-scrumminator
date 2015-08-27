# Setup cron
CronJob = require("cron").CronJob

class Scrum
    _robot = {}
    _room = {}

    constructor: (robot, time, room) ->
        _robot = robot
        _room = room

        cronJob = new CronJob(time, startScrum, null, true) #, TIMEZONE)

    startScrum = ->
        console.log "Scrum time! Please provide answers to the following:\n
            1. What have you done since yesterday?\n
            2. What are you planning to do today?\n
            3. Do you have any blocks\n
            4. Any tasks to add to the Sprint Backlog? (If applicable)\n
            5. Have you learned or decided anything new? (If applicable)"

        _robot.send
            room: _room
            """Scrum time! Please provide answers to the following:
            1. What have you done since yesterday?
            2. What are you planning to do today?
            3. Do you have any blocks
            4. Any tasks to add to the Sprint Backlog? (If applicable)
            5. Have you learned or decided anything new? (If applicable)"""


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