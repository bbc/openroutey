'use strict'
/**
 * These tests prove that the system handles different content types correctly
 */
let assert = require('assert'),
    expect = require('chai').expect,
    chai = require('chai')
chai.use(require('chai-http'))
let should = chai.should();
let testHelper = require('./test-helper')

describe("01 - content types", () => {
    it("start test origin", testHelper.startTestOrigin)
    it("can request text", done => {
        testHelper.get('/a/some-text').end((err, res) => {
            expect(err).to.be.null;
            res.should.have.status(200)
            res.text.should.equal('I need ☕️\n')
            expect(res).to.be.text;
            expect(res).to.have.header('x-router-cache', 'MISS')
            res.headers.etag.should.have.length.above(10)
            done()
        })
    })

    it("can request html", done => {
        testHelper.get('/a/some-html').end((err, res) => {
            expect(err).to.be.null;
            expect(res).to.be.html;
            res.should.have.status(200)
            res.text.should.equal('<h1>Some HTML 变形</h1>\n')
            done()
        })
    })

    it("can request json", done => {
        testHelper.get('/a/some-json').end((err, res) => {
            expect(err).to.be.null;
            expect(res).to.be.json;
            res.should.have.status(200)
            res.text.should.equal('{"some":"json"}\n')
            done()
        })
    })

    it("stop test origin", testHelper.stopTestOrigin)
})

/*

Headers:
- All headers should be passed through... check for Host
- Rewriting X-Route- headers

Routing:
- Malformed routing JSON
- Malformed envelope JSON
- Multiple route files
- Route files loaded via HTTP vs via FILE

When having an 'origins' section:
- Error messags - return or hide
- Redirects - can either be FOLLOWED or RETURNED
- Whether headers should be RETURNED or HIDDEN

*/
