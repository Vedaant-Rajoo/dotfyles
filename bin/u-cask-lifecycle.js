ObjC.import('AppKit');
ObjC.import('Foundation');
ObjC.import('stdlib');

var EX_USAGE = 64;
var EX_NOINPUT = 66;
var EX_SOFTWARE = 70;

function writeError(message) {
    var data = $(String(message) + '\n').dataUsingEncoding($.NSUTF8StringEncoding);
    $.NSFileHandle.fileHandleWithStandardError.writeData(data);
}

function fail(code, message) {
    writeError(message);
    $.exit(code);
}

function isNil(value) {
    return ObjC.unwrap(value) === undefined;
}

function unwrapString(value) {
    if (isNil(value)) {
        return null;
    }
    return String(ObjC.unwrap(value));
}

function resolvedFileURL(path) {
    return $.NSURL.fileURLWithPath(path).URLByResolvingSymlinksInPath;
}

function resolvedPath(url) {
    return unwrapString(url.URLByResolvingSymlinksInPath.path);
}

function parsePids(values) {
    var pids = [];
    var seen = {};

    for (var index = 0; index < values.length; index += 1) {
        var value = String(values[index]);
        if (!/^[0-9]+$/.test(value)) {
            fail(EX_USAGE, 'PID must be a positive decimal integer: ' + value);
        }

        var pid = Number(value);
        if (!Number.isSafeInteger(pid) || pid < 1 || pid > 2147483647) {
            fail(EX_USAGE, 'PID is outside the macOS process identifier range: ' + value);
        }

        if (!seen[pid]) {
            seen[pid] = true;
            pids.push(pid);
        }
    }

    return pids;
}

function matchingApplication(pid, bundleId) {
    var application = $.NSRunningApplication.runningApplicationWithProcessIdentifier(pid);
    if (isNil(application) || Boolean(application.terminated)) {
        return null;
    }

    if (unwrapString(application.bundleIdentifier) !== bundleId) {
        return null;
    }

    return application;
}

function inspectBundle(bundlePath) {
    var bundleURL = resolvedFileURL(bundlePath);
    var bundle = $.NSBundle.bundleWithURL(bundleURL);
    if (isNil(bundle)) {
        fail(EX_NOINPUT, 'Unreadable or invalid application bundle: ' + bundlePath);
    }

    var bundleId = unwrapString(bundle.bundleIdentifier);
    if (!bundleId) {
        fail(EX_NOINPUT, 'Application bundle has no bundle identifier: ' + bundlePath);
    }

    var targetPath = resolvedPath(bundleURL);
    var pids = [];
    var applications = $.NSWorkspace.sharedWorkspace.runningApplications;
    var count = Number(applications.count);

    for (var index = 0; index < count; index += 1) {
        var application = applications.objectAtIndex(index);
        if (Boolean(application.terminated) || unwrapString(application.bundleIdentifier) !== bundleId) {
            continue;
        }

        var runningURL = application.bundleURL;
        if (!isNil(runningURL) && resolvedPath(runningURL) !== targetPath) {
            continue;
        }

        pids.push(Number(application.processIdentifier));
    }

    return {
        path: targetPath,
        bundleId: bundleId,
        pids: pids
    };
}

function operateOnPids(command, bundleId, pids) {
    var matched = [];

    for (var index = 0; index < pids.length; index += 1) {
        var pid = pids[index];
        var application = matchingApplication(pid, bundleId);
        if (application === null) {
            continue;
        }

        if (command === 'terminate' && !Boolean(application.terminate)) {
            fail(EX_SOFTWARE, 'Failed to terminate PID ' + pid);
        }
        if (command === 'force-terminate' && !Boolean(application.forceTerminate)) {
            fail(EX_SOFTWARE, 'Failed to force-terminate PID ' + pid);
        }

        matched.push(pid);
    }

    return {
        bundleId: bundleId,
        pids: matched
    };
}

function run(argv) {
    if (argv.length === 0) {
        fail(EX_USAGE, 'Usage: u-cask-lifecycle.js <inspect|running|terminate|force-terminate> ...');
    }

    var command = String(argv[0]);

    try {
        if (command === 'inspect') {
            if (argv.length !== 2 || String(argv[1]).length === 0) {
                fail(EX_USAGE, 'Usage: u-cask-lifecycle.js inspect <bundle-path>');
            }
            return JSON.stringify(inspectBundle(String(argv[1])));
        }

        if (command === 'running' || command === 'terminate' || command === 'force-terminate') {
            if (argv.length < 2 || String(argv[1]).length === 0) {
                fail(EX_USAGE, 'Usage: u-cask-lifecycle.js ' + command + ' <bundle-id> [pid ...]');
            }

            var bundleId = String(argv[1]);
            return JSON.stringify(operateOnPids(command, bundleId, parsePids(argv.slice(2))));
        }

        fail(EX_USAGE, 'Unknown command: ' + command);
    } catch (error) {
        fail(EX_SOFTWARE, error);
    }
}
