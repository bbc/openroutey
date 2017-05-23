'use strict';
/**
 * These tests prove that the Redis cache does not cache private
 */
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai'),
    Redis = require('ioredis')
chai.use(require('chai-http'))
let should = chai.should()
let testHelper = require('./test-helper')

describe("03 - cache-control private", () => {
    it("start test origin", testHelper.startTestOrigin)

    let randomCacheId = Math.random()
    for (let i = 1; i<=2; i++) { // Loop twice to check second time isn't cached
        it("cache-control private should not set a cache header response, go " + i, done => {
            testHelper.get('/a/cache-private1').end(testHelper.checkFor({
                text: 'Secret 1\n',
                cache: 'MISS',
                cacheControl: 'max-age=2 private'
            }, done))
        })
    }

    for (let i = 1; i<=2; i++) { // Loop twice to check second time isn't cached
        it("cache-control private should not set a cache header response, example 2", done => {
            testHelper.get('/a/cache-private2').end(testHelper.checkFor({
                text: 'Secret 2\n',
                cache: 'MISS',
                cacheControl: 'private max-age=0'
            }, done))
        })
    }

})
