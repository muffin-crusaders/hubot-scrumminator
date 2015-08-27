# Description
#   A hubot script that does the things
#
# Configuration:
#   LIST_OF_ENV_VARS_TO_SET
#
# Commands:
#   hubot hello - <what the respond trigger does>
#   orly - <what the hear trigger does>
#
# Notes:
#   <optional notes required for the script>
#
# Author:
#   Aleksuei Riabtsev <aleksuei.riabtsev@ec.gc.ca>

# Models
Scrum = require('./model/scrum')



module.exports = (robot) ->

    scrumList = []

    robot.respond /scrum at (.*) in (.*)/i, (res) ->
        time = res.match[1]
        room = res.match[2]
        debugger
        scrum = new Scrum robot, time, room

        res.reply 'Scrum scheduled'

    robot.hear /orly/, (res) ->
        res.send "yarly"
