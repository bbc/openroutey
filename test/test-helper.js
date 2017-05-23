'use strict'
let chai = require('chai'),
    expect = chai.expect
chai.use(require('chai-http'))

let TestOrigin = require('./test-origin/test-origin')
let ts = new TestOrigin()

exports.domain = 'http://localhost:' + (process.env.OPENRESTY_PORT || 9000)

exports.startTestOrigin = function(done) {
    ts.init()
    ts.start().then(done)
}

exports.stopTestOrigin = function(done) {
    ts.stop().then(done)
}

exports.get = function(url) {
    console.log(`Calling Openresty with : [${exports.domain}${url}]`)
    return chai.request(exports.domain).get(url)
}

exports.checkFor = function(args, done) {
    return (err, res) => {
        if (!args.statusCode) args.statusCode = 200
        res.should.have.status(args.statusCode)
        expect(res).to.be.text;
        if (args.text) res.text.should.equal(args.text)
        if (args.cache) expect(res).to.have.header('x-router-cache', args.cache)
        if (args.cacheControl) expect(res).to.have.header('Cache-Control', args.cacheControl)
        done()
    }
}
