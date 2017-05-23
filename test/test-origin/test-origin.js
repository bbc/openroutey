'use strict'
let express = require('express'),
    path = require('path')

class TestOrigin {

    constructor(port) {
        this.port = port || process.env.TEST_ORIGIN_PORT || 9100
    }

    start() {
        if (!this.server) {
            this.server = this.app.listen(this.port)
            console.log('Magic happens on port ' + this.port)
        }
        return Promise.resolve()
    }

    stop() {
        this.server.close()
        delete this.server
        return Promise.resolve()
    }

    init() {
        if (this.initialised) return
        this.initialised = true
        this.app = express();
        var router = express.Router();

        // router.use(function(req, res, next) {
            // res.header("Access-Control-Allow-Origin", "*");
            // next();
        // });

        router.use((req, res, next) => {
            if (this.forceResponseStatus && !req.url.match('/a/force/.+')) {
                console.log(`[${req.url}] - forcing response ${this.forceResponseStatus}`)
                res.status(this.forceResponseStatus).send('Force response code ' + this.forceResponseStatus);
            }
            else {
                console.log(`Test origin called with: [${req.url}]`)
                next()
            }
        });

        router.get('/', (req, res) => {
            res.send('root')
        });

        router.get('/a/some-text', (req, res) => {
            res.set('Content-Type', 'text/plain');
            res.send('I need ☕️') // Emoji allows us to test UTF-8
        });

        router.get('/a/some-text-maxage-0', (req, res) => {
            res.set('Content-Type', 'text/plain')
            res.set('Cache-Control', 'max-age=0')
            res.send('I need ☕️')
        });

        router.get('/a/some-html', (req, res) => {
            res.set('Content-Type', 'text/html');
            res.send('<h1>Some HTML 变形</h1>')
        });

        router.get('/a/some-json', (req, res) => {
            res.set('Content-Type', 'application/json')
            res.send({some: "json"})
        });

        router.get('/a/statuses/400', (req, res) => {
            res.status(400).send('This is a 400')
        });

        router.get('/a/statuses/301', (req, res) => {
            res.redirect(301, '/a/statuses/301/new')
        });

        router.get('/a/statuses/302', (req, res) => {
            res.redirect(302, '/a/statuses/302/new')
        });

        router.get('/a/statuses/301/new', (req, res) => {
            res.send('You have been 301 redirected')
        });

        router.get('/a/statuses/302/new', (req, res) => {
            res.send('You have been 302 redirected')
        });

        router.get('/a/view/view1', (req, res) => {
            res.set('X-Route-Cache-Control', 'max-age=5');
            res.set('X-Route-X-Something', 'special');
            res.send({
                head: ["this is head 1", "this is head 2"],
                bodyInline: "this is body",
                bodyLast: ["this is body last 1", "this is body last 2"]
            })
        })

        router.get('/a/view/missing-bits', (req, res) => {
            res.send({
                bodyInline: "just-a-body",
            })
        })

        router.get('/a/view/bad-json', (req, res) => {
            res.set('Content-Type', 'application/json')
            res.send("{")
        })

        let cacheExamples = {}
        router.get('/a/cache-example/:id', (req, res) => {
            if (!cacheExamples[req.params.id]) cacheExamples[req.params.id] = 1
            res.set('Content-Type', 'text/plain')
            res.set('Cache-Control', 'max-age=1');
            res.send('💰cache-count:' + cacheExamples[req.params.id]++)
        })

        router.get('/a/force/off', (req, res) => {
            delete this.forceResponseStatus
            res.set('Content-Type', 'text/plain')
            res.send('OK forcing of status code is now switched off')
        })

        router.get('/a/force/:statusCode', (req, res) => {
            this.forceResponseStatus = req.params.statusCode
            res.set('Content-Type', 'text/plain')
            res.send('OK all responses will now respond with ' + this.forceResponseStatus)
        })

        router.get('/a/cache-private1', (req, res) => {
            res.set('Content-Type', 'text/plain')
            res.set('Cache-Control', 'max-age=2 private')
            res.send('Secret 1')
        });

        router.get('/a/cache-private2', (req, res) => {
            res.set('Content-Type', 'text/plain')
            res.set('Cache-Control', 'private max-age=0')
            res.send('Secret 2')
        });

        router.get('/encoded-url/%2Fa%2Ffoo%2Fbar', (req, res) => {
            res.set('Content-Type', 'text/plain')
            res.send('You visited /foo/bar')
        });

        this.app.use('/routes', express.static(path.join(__dirname, '/../config/')))
        this.app.use(router)
    }
}

module.exports = TestOrigin
