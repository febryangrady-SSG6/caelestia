pragma Singleton

import QtCore
import Quickshell

// Persists session drawer options outside the compiled C++ SessionConfig schema.
Singleton {
    id: root

    property alias showHibernate: sessionSettings.showHibernate

    Settings {
        id: sessionSettings

        property bool showHibernate: true

        category: "Session"
    }
}
