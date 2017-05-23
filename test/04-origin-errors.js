'use strict';
/**
 * These tests prove that the system behaves correctly whehn the origin fails or disappears.
 */
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai')
chai.use(require('chai-http'))
let should = chai.should();
let testHelper = require('./test-helper')

describe("04 - origin error - setup", setup)
describe("04 - origin error - returning 500", checkOriginFailingWith(500))
describe("04 - origin error - returning 202", checkOriginFailingWith(202))
describe("04 - origin error - origin missing", checkOriginMissing())

function setup() {
    it("start test origin", testHelper.startTestOrigin)
    it("call /a/some-text to prime cache", done => {
        testHelper.get('/a/some-text').end(testHelper.checkFor({statusCode: 200, text: 'I need ☕️\n'}, done))
    })

    it("call /a/some-text-maxage-0 to prime cache", done => {
        testHelper.get('/a/some-text-maxage-0').end((err, res) => {
            expect(err).to.be.null;
            res.should.have.status(200)
            expect(res).to.have.header('Cache-Control', 'max-age=0');
            done()
        })
    })
}

function checkOriginFailingWith(failureStatusCode) {
    return () => {
        it(`make origin return ${failureStatusCode} for all responses`, done => {
            testHelper.get('/a/force/' + failureStatusCode).end(testHelper.checkFor({statusCode: 200}, done))
        })

        it("call /a/some-text - it will not get stale from cache", done => {
            testHelper.get('/a/some-text').end(testHelper.checkFor({statusCode: failureStatusCode}, done))
        })

        it("call /a/some-text-maxage-0 - it will succeed stale", done => {
            testHelper.get('/a/some-text-maxage-0').end((err, res) => {
                expect(err).to.be.null;
                res.should.have.status(200)
                expect(res).to.have.header('Cache-Control', 'max-age=0');
                expect(res).to.have.header('X-Router-Cache', 'STALE');
                done()
            })
        })

        it("make origin succeed again", done => {
            testHelper.get('/a/force/off').end(testHelper.checkFor({statusCode: 200}, done))
        })

        it("call /a/some-text - it will be successful again", done => {
            testHelper.get('/a/some-text').end(testHelper.checkFor({statusCode: 200}, done))
        })

        it("call /a/some-text-maxage-0 - it will not serve stale any longer", done => {
            testHelper.get('/a/some-text-maxage-0').end((err, res) => {
                expect(err).to.be.null;
                res.should.have.status(200)
                expect(res).to.have.header('Cache-Control', 'max-age=0');
                expect(res).to.have.header('X-Router-Cache', 'EXPIRED');
                done()
            })
        })
    }
}

function checkOriginMissing() {
    return () => {
        it("stop test origin, intentionally", testHelper.stopTestOrigin)

        it("call /a/some-text - it will not get stale from cache", done => {
            testHelper.get('/a/some-text').end(testHelper.checkFor({statusCode: 502}, done))
        })

        it("call /a/some-text-maxage-0 - it will succeed stale", done => {
            testHelper.get('/a/some-text-maxage-0').end((err, res) => {
                expect(err).to.be.null;
                res.should.have.status(200)
                expect(res).to.have.header('Cache-Control', 'max-age=0');
                expect(res).to.have.header('X-Router-Cache', 'STALE');
                done()
            })
        })

        it("start test origin back up again", testHelper.startTestOrigin)

        it("call /a/some-text - it will be successful again", done => {
            testHelper.get('/a/some-text').end(testHelper.checkFor({statusCode: 200}, done))
        })

        it("call /a/some-text-maxage-0 - it will not serve stale any longer", done => {
            testHelper.get('/a/some-text-maxage-0').end((err, res) => {
                expect(err).to.be.null;
                res.should.have.status(200)
                expect(res).to.have.header('Cache-Control', 'max-age=0');
                expect(res).to.have.header('X-Router-Cache', 'EXPIRED');
                done()
            })
        })
    }
}
