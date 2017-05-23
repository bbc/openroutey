'use strict'
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai')
chai.use(require('chai-http'))
let should = chai.should();
let testHelper = require('./test-helper')

describe("06 - response codes", () => {
    it("start test origin", testHelper.startTestOrigin)

    it("400, defined in the routes", done => {
        testHelper.get('/a/400-example').end(testHelper.checkFor({
            statusCode: 400,
            text: 'nothing here\n'
        }, done))
    })

    it("200, defined in the routes", done => {
        testHelper.get('/a/ok').end(testHelper.checkFor({
            statusCode: 200,
            text: 'Yes thanks\n'
        }, done))
    })

    it("301, defined in the routes", done => {
        testHelper.get('/a/redirect').redirects(0).end((err, res) => {
            res.should.have.status(301)
            expect(res).to.redirectTo('/a/happy-path');
            done()
        })
    })

    it("302, defined in the routes", done => {
        testHelper.get('/a/redirect2').redirects(0).end((err, res) => {
            res.should.have.status(302)
            expect(res).to.redirectTo('/a/happy-path');
            done()
        })
    })

    it("301, received from origin", done => {
        testHelper.get('/a/statuses/301').redirects(0).end((err, res) => {
            res.should.have.status(301)
            expect(res).to.redirectTo('/a/statuses/301/new');
            done()
        })
    })

    it("302, received from origin", done => {
        testHelper.get('/a/statuses/302').redirects(0).end((err, res) => {
            res.should.have.status(302)
            expect(res).to.redirectTo('/a/statuses/302/new');
            done()
        })
    })

    it("400, received from origin", done => {
        testHelper.get('/a/statuses/400').end(testHelper.checkFor({
            statusCode: 400,
            text: '400\n'
        }, done))
    })

    it("404, received from origin", done => {
        testHelper.get('/a/statuses/complete-nonsense').redirects(0).end((err, res) => {
            res.should.have.status(404)
            done()
        })
    })

})
