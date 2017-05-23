'use strict'
/**
 * These tests check the 'envelope' transform
 */
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai')
chai.use(require('chai-http'))
let should = chai.should();
let testHelper = require('./test-helper')

describe("07 - routing files", () => {
    it("start test origin", testHelper.startTestOrigin)

    it("can handle an encoded url", done => {
        testHelper.get('/a/foo/bar').end(testHelper.checkFor({
            text: 'You visited /foo/bar\n'
        }, done))
    })
})
