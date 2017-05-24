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

```
openresty
# Or, reload if already running:
openresty -s reload
```

Now visit any URL on the server. E.g. if your server is running locally, on port 8000, visit http://localhost:8000/. You should get the message 'Hello world'.

## JSON route definitions

Routes are defined in JSON, and the 'Hello world' example above is a simple example of this.

TODO Write this doc


### Regular expressions

* Lua regular expressions do not have full POSIX support.
* If you need to provide a dash in a Lua regex, escape it with a %, e.g. "^/foo%-bar"
* To test regular expressions use `lua` on the command line, e.g.

```
    echo 'print(string.match("foo-bar", "foo%-bar"))' | lua
```

## Testing

Testing is done via a Node.JS script (to simulate an origin server), and the Mocha test framework.

```
cd test
npm install # only needs to be done once
npm test
```
