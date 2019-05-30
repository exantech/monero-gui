import QtQuick 2.0

QtObject {
    property bool loaded: false
    property string state
    property int signaturesRequired
    property int participantsCount
    property string metaPath

    function save(path) {
        if (!path) {
            path = metaPath;
        }

        if (!path.startsWith("file://")) {
            path = "file://" + path;
        }

        metaPath = path;
        var data = JSON.stringify({
            'state': state,
            'signaturesRequired': signaturesRequired,
            'participantsCount': participantsCount
        });

        var success = false;
        var req = new XMLHttpRequest();
        req.onreadystatechange = function () {
            if (req.readyState === 2) {
                success = true;
            }
        };

        req.open("PUT", path, false);
        req.send(data);

        if (!success) {
            console.warn("failed to write to " + path + " file");
        }

        return success;
    }

    function load(path) {
        try {
            if (!path.startsWith("file://")) {
                path = "file://" + path;
            }

            var success = false;
            var req = new XMLHttpRequest();
            req.onreadystatechange = function () {
                if (req.readyState === 2) {
                    success = true;
                }
            };

            req.open("GET", path, false);
            req.send(null);

            if (!success) {
                console.warn("failed to open " + path + " file");
            }

            var obj = JSON.parse(req.responseText);
            state = obj.state;
            signaturesRequired = obj.signaturesRequired;
            participantsCount = obj.participantsCount;

            loaded = true;
            return true;
        } catch (e) {
            console.warn("failed to read multisig wallet meta (" + path + "): " + e);
        }

        return false;
    }
}
