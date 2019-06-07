import QtQuick 2.0

QtObject {
    property bool loaded: false
    property string state
    property int signaturesRequired
    property int participantsCount
    property int keysRounds: 0
    property string metaPath

    function save(path) {
        if (!path) {
            path = metaPath;
        }

        metaPath = path;
        var obj = {
            'state': state,
            'signaturesRequired': signaturesRequired,
            'participantsCount': participantsCount,
            'keysRounds': keysRounds
        };

        var data = JSON.stringify(obj);

        if (!oshelper.writeFile(data, path)) {
            console.warn("failed to write to " + path + " file");
            return false;
        }

        return true;
    }

    function load(path) {
        try {
            var res = oshelper.readFile(path);
            if (res.error) {
                console.warn("failed to read " + path + " file: " + res.errorString);
                return false
            }

            var obj = JSON.parse(res.result);
            state = obj.state;
            signaturesRequired = obj.signaturesRequired;
            participantsCount = obj.participantsCount;
            keysRounds = obj.keysRounds;

            metaPath = path;
            loaded = true;
            return true;
        } catch (e) {
            console.warn("failed to read multisig wallet meta (" + path + "): " + e);
        }

        return false;
    }
}
