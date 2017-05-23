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

describe("05 - transforms - envelope", () => {
    it("start test origin", testHelper.startTestOrigin)

    it("can request envelope-transformed html", done => {
        testHelper.get('/a/view/view1').end((err, res) => {
            expect(err).to.be.null;
            expect(res).to.be.html;
            res.should.have.status(200)
            let withoutTimestamp = res.text.replace(/\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/, 'TIMESTAMP')
            withoutTimestamp.should.equal(
              '<!DOCTYPE html>\n<html>\n' +
              '<head>\n' +
              'this is head 1this is head 2\n' +
              '</head>\n' +
              '<body>\n' +
              'this is bodythis is body last 1this is body last 2\n' +
              '<!-- Generated by Morph Router at TIMESTAMP -->\n' +
              '</body>\n' +
              '<html>\n'
            )

            expect(res).to.have.header('Cache-Control', 'max-age=5')
            expect(res).to.have.header('X-Something', 'special')
            done()
        })
    })

    it("can handle an envelope with missing bits", done => {
        testHelper.get('/a/view/missing-bits').end((err, res) => {
            expect(err).to.be.null;
            expect(res).to.be.html;
            res.should.have.status(200)
            let withoutTimestamp = res.text.replace(/\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/, 'TIMESTAMP')
            withoutTimestamp.should.equal(
              '<!DOCTYPE html>\n<html>\n' +
              '<head>\n\n' +
              '</head>\n' +
              '<body>\n' +
              'just-a-body\n' +
              '<!-- Generated by Morph Router at TIMESTAMP -->\n' +
              '</body>\n' +
              '<html>\n'
            )
            done()
        })
    })

    it("can handle bad JSON in envelope response", done => {
        testHelper.get('/a/view/bad-json').end((err, res) => {
            res.should.have.status(500)
            res.text.should.equal('Invalid Envelope JSON\n')
            done()
        })
    })
})