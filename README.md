# OpenRoutey

OpenRoutey is a Lua library that allows OpenResty (based on Nginx) to have dynamically-generated routes to origins (backends). Openroutey consults JSON route definitions, either local to the server or served elsewhere, to determine how to route traffic. Other features include the ability to create  *transforms* on responses, and the use of *Redis* as a response cache.

## Installation

* First, make sure you have OpenResty installed. See https://openresty.org/en/installation.html
* OpenRoutey can be installed using opm, OpenResty's package manager:

```
   # Pick an installation directory that's suitable for your environment:
   opm --install-dir="/usr/lib/openresty/lualib" install openroutey
```

## Setup

First, create a basic routes file.
You can call it whatever you like - `routes.json` is a good suggestion.
You can put it anywhere that OpenResty can access - such as `/etc/openrsesty` or `/usr/local/etc/openresty`.

Add the following to the file:

```
{
    "routes" : [
        {
            "pathMatch" : "^/",
            "status" : 200,
            "body" : "Hello world"
        }
    ]
}
```

This basically says 'respond to everything with the text "Hello world" and a 200 (OK) response code.'
(We'll look at more complex routing in 'JSON route definitions', below.)

### Setting up OpenResty

Edit your OpenResty's `nginx.conf`. You may find it in `/etc/openresty` or `/usr/local/etc/openresty`.

Within the 'http' section, add the path that openroutey was installed above, with `/?.lua;;` at the end, e.g.

```
    lua_package_path "/usr/lib/openresty/lualib/?.lua;;";
```

Then beneath it, initialise OpenRoutey with the following:

```
    lua_shared_dict openroutey 100k;
    init_by_lua '
        openroutey = require "openroutey"
        openroutey.init({
            routesFile = "/path/to/routes.json",
            redisHost = "127.0.0.1",
            redisPort = 6379
        })
    ';
```

Replace `/path/to/routes.json` with the location of the basic routes file you made above.

Then, in the *Server* section, remove any existing `location` entries and add the following:

```
    location ~ ^/call(?<path>/.*) {
        proxy_pass_request_headers off;

        #internal; # enable for production env
        proxy_set_header Accept-Encoding ''; # don't accept gzipped responses
        # If you need to set client-side SSL certificates, do it here
        proxy_set_header If-None-Match $arg_etag;

        resolver 8.8.8.8; # Change this when on AWS
        set_unescape_uri $domain $arg_domain;
        set_unescape_uri $allargs $arg_allargs;
        proxy_pass $domain$path$allargs;
    }

    location / {
        lua_code_cache off; # remove when going live
        content_by_lua_block { openroutey.go() }
    }
```

Now start OpenResty:

```bash
openresty
# Or, reload if already running:
openresty -s reload
```

Now visit any URL on the server. E.g. if your server is running locally, on port 8000, visit http://localhost:8000/. You should get the message 'Hello world'.

## JSON route definitions

Routes are defined in JSON, and the 'Hello world' example above is a simple example of this.

Routes files should be an object (associative array) which must contain a "routes" entry. It may also contain an "origins" entry.

For example this routes file routes all traffic to port 8000 on the same box:

```json
{
    "routes" : [
        {
            "pathMatch" : "^/",
            "originId": "localhost"
        }
    ],
    "origins" : [
        {
            "id": "localhost",
            "originProtocolAndDomain": "http://127.0.0.1:8000",
        }
    ]
}
```

The 'routes' and 'origins' arrays

### The 'routes' array

* Routes is an ordered array of route rules.
* Ordering is important. The first rule that matches will be used.
* Each entry should be an object.
* The object must contain `pathMatch`.
 * This is a regular expression of the path for the rule to match.
 * Note that these are Lua regular expressions, which are different from Nginx, and do not have full POSIX support. See 'Regular expressions' below for more.

There are three different types of routes entries

#### Routes entry type #1: Static responses

For a set response, provide `status` and optionally `body`.
For example, to return the text `Hello world`, with a 200 (OK) status code:

```json
        {
            "pathMatch" : "^/hello$",
            "status" : 200,
            "body" : "Hello world"
        }
```

This is great for redirects, where you can also provide `location` of the place to redirect to e.g.

```json

        {
            "pathMatch" : "^/promo$",
            "status" : 302,
            "location": "/some/full/uri",
        }
```

It also is useful to explicitly 404 (Not Found) a URL:

```json

        {
            "pathMatch" : "^/some-old-uri$",
            "status" : 404
        }
```

#### Routes entry type #2: Origin responses

To route the request to an origin (backend), provide the originId, from an origin defined in the `origins` section.

```json
        {
            "pathMatch" : "^/shopping",
            "originId": "shopping-service"
        }
```

By default, the origin will be provided with the same path. Alternatively, the path can be set with `originPath`. Examples:

* To hard-code the path:

```
    "originPath": "/some/path"
```

* To prefix the path:

```
    "originPath": "/some/prefix/${uri}
```

* To include an encoded path:

```
    "originPath": "/path/${uriEncoded}
```

#### Routes entry type #3: Reference another routes file

If you'd like your routes to be split into more than one file, use a routing rule to reference it.

In this example, any path starting with `/a` will be sent to `routes-a.json`, and any path starting with `/b` or `/c` will be sent to `routes-b-and-c.json`.

```json
        {
            "pathMatch" : "^/a",
            "routesFile": "routes-a.json"
        },
        {
            "pathMatch" : "^/(b|c)",
            "routesFile": "routes-b-and-c.json"
        }
```

### The 'origins' array

The `origins` entry in a routes file defines origins (backends) that requests can be routed to. The order of the array is not important. Each origin must haven an `id` (string) and `originProtocolAndDomain` (string). For example:

```json
        {
            "id": "my-s3-bucket",
            "originProtocolAndDomain": "http://my-s3-bucket.s3.amazonaws.com"
        }
```

Optionally, `originPathPostfix` can be provided, to postfix something on to every path.

Paths are created as follows:

```
<originProtocolAndDomain><originPath><originPathPostfix>
```

### Regular expressions

* The `pathMatch` entry is always a regular expression.
* Don't forget to start with `^` and end with `$` if you need to fully match the path.
  * For example `/hi` will match `/hi`, `/hit`, and `/foo/hit`. To match just `/hi`, use `^/hi$`
* Lua regular expressions do not have full POSIX support.
* If you need to provide a dash in a Lua regex, escape it with a %, e.g. "^/foo%-bar"
* To test regular expressions use `lua` on the command line, e.g.

```
    echo 'print(string.match("foo-bar", "foo%-bar"))' | lua
```

## Testing

Testing is done via a Node.JS script (to simulate an origin server), and the Mocha test framework.

```bash
cd test
npm install # only needs to be done once
npm test
```
