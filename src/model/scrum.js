const CronJob = require('cron').CronJob;
const Gitter = require('node-gitter');
const RomanNumerals = require('roman-numerals');
const phrases = require('../phrases.json');

const gitter = new Gitter(process.env.HUBOT_GITTER2_TOKEN);

class Scrum {
    constructor(robot, time, room, id) {
        this.id_count = 1;

        this._robot = robot;
        this._room = room;
        this._time = time;
        this._id = id;
        this._active = true;

        // stores answers + other info for scrum
        this._scrumLog = {};

        // flag for activity during scrum
        this._recentMessage = true;

        this.cronJob = new CronJob(time, this.startScrum, null, true, null, this);

        // DEBUG: this will immediately start scrum in CyberTests
        /* console.log('scrum', time, room, id);
        if (room === 'AleksueiR/CyberTests') {
            console.log('start');
            this.startScrum.call(this);
        } */
    }

    startScrum() {
        console.log(`[hubot-scrumminator] Starting scrum in ${this._room}`);

        this._robot.send(
            { room: this._room },
            'Scrum time! Please provide answers to the following: \n' +
                '1. What have you done since yesterday?\n' +
                '2. What are you planning to do today?\n' +
                '3. Do you have any blocks\n' +
                '4. Any tasks to add to the Sprint Backlog? (If applicable)\n' +
                '5. Have you learned or decided anything new? (If applicable)'
        );

        this.thanked = [];

        this._timeoutHandle = setTimeout(this.endScrum, 900000);

        // Add some extra info to the scrum log so its more identifiable
        const now = new Date();
        const day = now.getDate();
        const month = now.getMonth() + 1;
        const year = now.getFullYear();
        const hour = now.getHours();
        const minutes = now.getMinutes();

        this._scrumLog['timestamp'] =
            day.toString() + '/' + month.toString() + '/' + year.toString() + ' at ' + hour.toString() + ':' + minutes.toString();
        this._scrumLog['participants'] = [];

        this._robot.brain.data._private.scrumminator.logs[this._id] = this._scrumLog;

        // Find current room
        gitter.rooms.join(this._room).then(room => {
            // Request to get list of users in the scrum room
            room.subscribe();
            console.log('[hubot-scrumminator] room.subscribe');

            // Each message is given an operation to signal if its a new message, edit, "viewed by" etc.
            // 'create' is used for new messages
            room.on('chatMessages', message => {
                console.log('[hubot-scrumminator] chatMessage received');
                if (message.operation === 'create') {
                    console.log('[hubot-scrumminator] trying to parse');
                    this.parseLog(message);
                }
            });

            // Request to get list of users in the scrum room
            room.users().then(users => {
                for (let user of Array.from(users)) {
                    // Create a section for everyone but the bot
                    if (user.username !== process.env.HUBOT_NAME && user.displayName !== process.env.HUBOT_NAME) {
                        this._scrumLog.participants.push({
                            name: user.username,
                            displayName: user.displayName,
                            answers: new Array(5).fill(null)
                        });
                    }
                }
                this._robot.brain.save;
            });
        });
    }

    parseLog(response) {
        const data = response.model;
        // split up lines in message since most users will paste all of their answers together
        const messages = data.text.split('\n');
        // get user info
        const userid = data.fromUser.username;
        const displayname = data.fromUser.displayName;

        console.log(`[hubot-scrumminator] message: ${messages}`);

        // const answerPattern = new RegExp(/^[^A-Za-z1-9]*?([1-5]|I{1,3}|IV|V).*?(?!_)(\w.+)$/i);
        const answerPattern = new RegExp(/^([1-5])\./i);

        messages.forEach(message => {
            if (userid === process.env.HUBOT_NAME || displayname === process.env.HUBOT_NAME /* && answerPattern.test(message) */) {
                return;
            }

            console.log(`[hubot-scrumminator] Received answer from ${userid}`);

            // reset the timeout which ends scrum
            if (this._timeoutHandle) {
                clearTimeout(this._timeoutHandle);
                this._timeoutHandle = undefined;
            }

            const num = (answerPattern.exec(message.trim()) || [, -1])[1];
            if (0 > num || num > 5) {
                return;
            }

            this._timeoutHandle = setTimeout(this.endScrum, 900000);

            this._scrumLog.participants.forEach(user => {
                // check to see if we've found the right user and this we havent received this answer before
                if (user.name !== userid || user.answers[num - 1] !== null) {
                    return;
                }

                user.answers[num - 1] = message;
                console.log(`[hubot-scrumminator] Saved answer ${num}: ${message}`);

                // Check to see if at least answers 1-3 have been given by the user, thank them if they have
                if (user.answers.slice(0, 3).filter(a => a).length >= 3) {
                    if (this.thanked.indexOf(userid) < 0) {
                        console.log(`[hubot-scrumminator] Thanked used ${userid}`);

                        this.thanked.push(userid);

                        const reply = phrases.thanks[Math.floor(Math.random() * phrases.thanks.length)];

                        this._robot.send({ room: this._room }, reply.replace('[username]', displayname.split(' ')[0]));
                    }

                    this._robot.brain.save();
                }
            });
        });
    }

    endScrum() {
        console.log(`[hubot-scrumminator] Ending scrum in ${this._room}`);
        clearTimeout(this._timeoutHandle);

        this._timeoutHandle = undefined;

        // Unsubscribe from the rooms message stream
        gitter.rooms.join(this._room).then(room => room.unsubscribe());

        this._robot.brain.save();
    }

    stopCronJob() {
        this.cronJob.stop();
        this._active = false;
    }

    startCronJob() {
        this.cronJob.start();
        this._active = true;
    }

    toPrintable() {
        return this._room.toString() + ' at `' + this._time.toString() + '` ' + (this._active ? '(active)' : '(inactive)');
    }

    getId() {
        return this._id;
    }
}

module.exports = Scrum;
