'use strict';
/**
 * These tests prove that the Redis cache works as expected
 */
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai'),
    Redis = require('ioredis')
chai.use(require('chai-http'))
let should = chai.should()
let testHelper = require('./test-helper')

describe("02 - cache", () => {
    it("start test origin", testHelper.startTestOrigin)

    let randomCacheId = Math.random()
    it("1st request for cached content - get MISS", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:1\n',
            cache: 'MISS',
            cacheControl: 'max-age=1'
        }, done))
    })

    it("2nd request for cached content - get HIT", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:1\n',
            cache: 'HIT',
            cacheControl: 'max-age=1'
        }, done))
    })

    it("wait a second for cache to time out", done => {
        setTimeout(done, 1000)
    })

    it("3rd request for cached content, now that cache has expired", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:2\n',
            cache: 'EXPIRED',
            cacheControl: 'max-age=1'
        }, done))
    })

    it("4th request for cached content, and it is a HIT again", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:2\n',
            cache: 'HIT',
            cacheControl: 'max-age=1'
        }, done))
    })

    it("intentionally tell Redis to stop responding", done => {
        let redis = new Redis()
        redis.client('pause', 1000, (err, result) => {
            expect(err).to.equal(null)
            expect(result).to.equal('OK')
            done()
        })
    })

    it("5th request for cached content, and it is a MISS  as cache is missing", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:3\n',
            cache: 'MISS',
            cacheControl: 'max-age=1'
        }, done))
    })

    it("wait a second for Redis to come back online", done => {
        setTimeout(done, 1000)
    })

    it("6th request for cached content, and it is a MISS  as cache is missing", done => {
        testHelper.get('/a/cache-example/' + randomCacheId).end(testHelper.checkFor({
            text: '💰cache-count:4\n',
            cache: 'EXPIRED',
            cacheControl: 'max-age=1'
        }, done))
    })
})
