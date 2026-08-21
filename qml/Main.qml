import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Orby 1.0

Window {
    id: window
    width: 520
    height: 740
    visible: true
    title: "Orby"
    color: md.background

    // ════════════════════════════════════════════════════════════════
    //  Google Material 3 — Bold Dark Design Tokens
    // ════════════════════════════════════════════════════════════════
    QtObject {
        id: md

        // Primary: Google Vibrant Blue
        readonly property color primary:               "#A8C7FA"
        readonly property color primaryFg:              "#062E6F"
        readonly property color primaryContainer:       "#0842A0"
        readonly property color primaryContainerFg:     "#D3E3FD"

        // Secondary: Vibrant Cyan Accent
        readonly property color secondary:              "#7FCFFF"
        readonly property color secondaryFg:            "#003549"
        readonly property color secondaryContainer:     "#004D68"
        readonly property color secondaryContainerFg:   "#C2E7FF"

        // Tertiary: Google Green / Active Spoofing Accent
        readonly property color tertiary:               "#6DD58C"
        readonly property color tertiaryFg:             "#0A3818"
        readonly property color tertiaryContainer:      "#0E3E1E"
        readonly property color tertiaryContainerFg:    "#C4EED0"

        // Error: Google Red
        readonly property color error:                  "#FF897D"
        readonly property color errorFg:                "#601410"
        readonly property color errorContainer:         "#410E0B"
        readonly property color errorContainerFg:       "#F9DEDC"

        // Surfaces & Elevation (Google Material 3 Dark)
        readonly property color background:             "#111318"
        readonly property color surface:                "#111318"
        readonly property color surfaceContainerLowest: "#0C0E12"
        readonly property color surfaceContainerLow:    "#191C20"
        readonly property color surfaceContainer:       "#1D2024"
        readonly property color surfaceContainerHigh:   "#282A2F"
        readonly property color surfaceContainerHighest:"#33353A"
        readonly property color surfaceBright:          "#37393E"

        // High-contrast Outlines & Borders (Bolder Borders)
        readonly property color outline:                "#8E9199"
        readonly property color outlineVariant:         "#44474E"
        readonly property color borderActive:           "#A8C7FA"
        readonly property color borderTertiary:         "#6DD58C"
        readonly property color borderError:            "#FF897D"

        // Foreground / On-surface
        readonly property color surfaceFg:              "#E2E2E6"
        readonly property color surfaceVariantFg:       "#C4C6D0"
    }

    // ════════════════════════════════════════════════════════════════
    //  Backend instances
    // ════════════════════════════════════════════════════════════════
    DiscordApi {
        id: discordApi
        Component.onCompleted: fetchGames()
        onErrorOccurred: (msg) => console.warn("[DiscordApi]", msg)
    }

    ProcessSpoofer {
        id: spoofer
        onErrorOccurred: (msg) => console.warn("[Spoofer]", msg)
    }

    // Helper to find human-readable game name for an executable
    function getGameTitle(execName) {
        if (!discordApi || !discordApi.games) return execName
        let match = discordApi.games.find(g => g.primaryExecutable === execName)
        return match ? match.name : execName
    }

    // ════════════════════════════════════════════════════════════════
    //  Filtering logic
    // ════════════════════════════════════════════════════════════════
    property var filteredGames: []

    function updateFilter() {
        let query = searchInput.text.toLowerCase().trim()
        if (query === "") {
            filteredGames = discordApi.games
        } else {
            filteredGames = discordApi.games.filter(g => g.name.toLowerCase().includes(query))
        }
        gameListView.model = filteredGames
    }

    Connections {
        target: discordApi
        function onGamesChanged() { updateFilter() }
    }

    // ════════════════════════════════════════════════════════════════
    //  Main Layout
    // ════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        // ── Top App Bar ──
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 2
            spacing: 12

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true

                RowLayout {
                    spacing: 8
                    Text {
                        text: "Orby"
                        color: md.surfaceFg
                        font.family: "Inter"
                        font.pixelSize: 26
                        font.weight: Font.Bold
                        font.letterSpacing: -0.5
                    }
                    Rectangle {
                        color: md.primaryContainer
                        border.color: md.primary
                        border.width: 1.5
                        radius: 6
                        implicitWidth: 54
                        implicitHeight: 20
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "LINUX"
                            color: md.primaryContainerFg
                            font.family: "Inter"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                        }
                    }
                }

                Text {
                    text: "Discord Game Presence Spoofer"
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }
        }

        // ── Status Card (Clickable to view active games dialog) ──
        Rectangle {
            id: statusCard
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            radius: 10
            color: spoofer.isSpoofing ? md.tertiaryContainer : md.surfaceContainer
            border.color: {
                if (spoofer.isSpoofing) {
                    return statusCardMouse.containsMouse ? md.primary : md.tertiary
                }
                return statusCardMouse.containsMouse ? md.outline : md.outlineVariant
            }
            border.width: spoofer.isSpoofing ? 2 : 1.5

            Behavior on color {
                ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: statusCardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: spoofer.isSpoofing ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (spoofer.isSpoofing) {
                        activeGamesModal.open()
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 14
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                spacing: 12

                // Pulsing status indicator dot
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: spoofer.isSpoofing ? md.tertiary : md.outline
                    Layout.alignment: Qt.AlignVCenter

                    SequentialAnimation on opacity {
                        running: spoofer.isSpoofing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    }

                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    Component.onCompleted: opacity = 1.0
                    onColorChanged: if (!spoofer.isSpoofing) opacity = 1.0
                }

                // Status text
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: 8
                        Text {
                            text: {
                                if (!spoofer.isSpoofing) return "INACTIVE"
                                let count = spoofer.spoofedCount
                                return "SPOOFING " + count + " GAME" + (count !== 1 ? "S" : "")
                            }
                            color: spoofer.isSpoofing ? md.tertiary : md.outline
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.1

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }

                        // "Click to view" badge hint
                        Rectangle {
                            visible: spoofer.isSpoofing
                            color: md.surfaceContainerHigh
                            border.color: md.outlineVariant
                            border.width: 1
                            radius: 4
                            implicitWidth: 84
                            implicitHeight: 18

                            Text {
                                anchors.centerIn: parent
                                text: "Click to view ↗"
                                color: md.surfaceVariantFg
                                font.family: "Inter"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        text: {
                            if (!spoofer.isSpoofing) return "Select a game below to begin"
                            let count = spoofer.spoofedCount
                            if (count === 1) {
                                return getGameTitle(spoofer.spoofedProcesses[0]) + " is active"
                            }
                            return count + " games are currently spoofing"
                        }
                        color: md.surfaceFg
                        font.family: "Inter"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Stop All button
                Button {
                    id: stopAllBtn
                    visible: spoofer.isSpoofing
                    text: "Stop All"
                    font.family: "Inter"
                    font.weight: Font.Bold
                    font.pixelSize: 12
                    Layout.preferredWidth: 82
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter

                    background: Rectangle {
                        radius: 8
                        color: stopAllBtn.hovered ? "#5C1B1E" : md.errorContainer
                        border.color: md.borderError
                        border.width: 1.5
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: md.error
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font: parent.font
                    }

                    onClicked: spoofer.stopAllSpoofing()
                }
            }
        }

        // ── Search Bar (Bold Google Material 3) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 10
            color: md.surfaceContainerHigh
            border.color: searchInput.activeFocus ? md.primary : md.outlineVariant
            border.width: searchInput.activeFocus ? 2 : 1.5

            Behavior on border.color {
                ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                // Search icon
                Text {
                    text: "🔍"
                    font.pixelSize: 14
                    color: md.surfaceVariantFg
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: md.surfaceFg
                    font.family: "Inter"
                    font.pixelSize: 14
                    selectionColor: md.primaryContainer
                    selectedTextColor: md.primaryContainerFg
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search games or executables..."
                        color: md.outline
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                        visible: !parent.text && !parent.activeFocus
                    }

                    onTextChanged: updateFilter()
                }

                // Clear button
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 24
                    height: 24
                    radius: 6
                    color: clearMouse.containsMouse ? md.surfaceContainerHighest : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        color: md.surfaceFg
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.focus = false
                        }
                    }
                }
            }
        }

        // ── Game count row ──
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 2
            Layout.rightMargin: 2

            Text {
                text: {
                    if (discordApi.isLoading) return "Loading library..."
                    let total = gameListView.count
                    return total + " game" + (total !== 1 ? "s" : "") + (searchInput.text ? " matching" : " available")
                }
                color: md.outline
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: Font.Medium
            }

            Item { Layout.fillWidth: true }

            Text {
                visible: spoofer.isSpoofing
                text: spoofer.spoofedCount + " active"
                color: md.tertiary
                font.family: "Inter"
                font.pixelSize: 12
                font.weight: Font.Bold
            }
        }

        // ── Game List ──
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            clip: true

            ListView {
                id: gameListView
                anchors.fill: parent
                anchors.rightMargin: 6
                spacing: 8
                model: filteredGames
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400
                reuseItems: true

                ScrollBar.vertical: ScrollBar {
                    id: mainScrollBar
                    policy: ScrollBar.AsNeeded
                    anchors.right: parent.right
                    anchors.rightMargin: -5
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: md.outlineVariant
                        opacity: mainScrollBar.active ? 0.9 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                delegate: Rectangle {
                    id: gameTile
                    width: gameListView.width
                    height: 64
                    radius: 8

                    property bool isThisActive: spoofer.isSpoofingProcess(modelData.primaryExecutable)

                    Connections {
                        target: spoofer
                        function onSpoofedProcessesChanged() {
                            gameTile.isThisActive = spoofer.isSpoofingProcess(modelData.primaryExecutable)
                        }
                    }

                    color: {
                        if (gameTile.isThisActive) return md.tertiaryContainer
                        if (tileMouseArea.containsMouse) return md.surfaceContainerHighest
                        return md.surfaceContainer
                    }
                    border.color: {
                        if (gameTile.isThisActive) return md.borderTertiary
                        if (tileMouseArea.containsMouse) return md.primary
                        return md.outlineVariant
                    }
                    border.width: gameTile.isThisActive ? 2 : 1.5

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        anchors.topMargin: 8
                        anchors.bottomMargin: 8
                        spacing: 12

                        // Game icon block
                        Rectangle {
                            width: 38
                            height: 38
                            radius: 6
                            color: gameTile.isThisActive ? md.tertiary : md.primaryContainer
                            border.color: gameTile.isThisActive ? md.tertiaryFg : md.primary
                            border.width: 1.5
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                color: gameTile.isThisActive ? md.tertiaryFg : md.primaryContainerFg
                                font.family: "Inter"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }
                        }

                        // Game info
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: modelData.name
                                color: md.surfaceFg
                                font.family: "Inter"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.primaryExecutable
                                color: gameTile.isThisActive ? md.tertiary : md.outline
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Spoof / Stop Toggle Button
                        Button {
                            id: spoofBtn
                            text: gameTile.isThisActive ? "Stop" : "Spoof"
                            font.family: "Inter"
                            font.weight: Font.Bold
                            font.pixelSize: 12
                            Layout.preferredWidth: 76
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignVCenter

                            background: Rectangle {
                                radius: 8
                                color: {
                                    if (gameTile.isThisActive) {
                                        return spoofBtn.hovered ? "#5C1B1E" : md.errorContainer
                                    }
                                    if (spoofBtn.hovered) return md.primaryContainer
                                    return md.surfaceContainerHigh
                                }
                                border.color: {
                                    if (gameTile.isThisActive) return md.borderError
                                    if (spoofBtn.hovered) return md.primary
                                    return md.outlineVariant
                                }
                                border.width: 1.5

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                            }

                            contentItem: Text {
                                text: spoofBtn.text
                                color: {
                                    if (gameTile.isThisActive) return md.error
                                    if (spoofBtn.hovered) return md.primary
                                    return md.surfaceFg
                                }
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: spoofBtn.font
                            }

                            onClicked: {
                                if (gameTile.isThisActive) {
                                    spoofer.stopSpoofingProcess(modelData.primaryExecutable)
                                } else {
                                    spoofer.startSpoofing(modelData.primaryExecutable,
                                                          modelData.name,
                                                          modelData.steamAppId ?? "")
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: tileMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }

            // ── Loading state ──
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 14
                visible: discordApi.isLoading

                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: "transparent"
                    border.color: md.primary
                    border.width: 3
                    Layout.alignment: Qt.AlignHCenter

                    Rectangle {
                        width: 16
                        height: 16
                        color: md.background
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: discordApi.isLoading
                    }
                }

                Text {
                    text: "Fetching Discord game database..."
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ── Empty state ──
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8
                visible: !discordApi.isLoading && gameListView.count === 0

                Text {
                    text: "🎮"
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: searchInput.text ? "No games match '" + searchInput.text + "'" : "No games available"
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Active Spoofed Games Modal / Dialog
    // ════════════════════════════════════════════════════════════════
    Rectangle {
        id: activeGamesModal
        anchors.fill: parent
        color: "#B3000000"
        visible: false
        z: 999

        function open() {
            visible = true
        }

        function close() {
            visible = false
        }

        // Close on backdrop click
        MouseArea {
            anchors.fill: parent
            onClicked: activeGamesModal.close()
        }

        // Auto-close if no games are spoofing anymore
        Connections {
            target: spoofer
            function onSpoofedProcessesChanged() {
                if (!spoofer.isSpoofing && activeGamesModal.visible) {
                    activeGamesModal.close()
                }
            }
        }

        // Dialog Content Box
        Rectangle {
            id: dialogBox
            width: Math.min(parent.width - 40, 460)
            height: Math.min(parent.height - 80, 480)
            anchors.centerIn: parent
            radius: 12
            color: md.surfaceContainerHigh
            border.color: md.outlineVariant
            border.width: 2

            // Prevent clicks inside dialog from dismissing modal
            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                // Dialog Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: md.tertiary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        text: "Active Spoofed Games"
                        color: md.surfaceFg
                        font.family: "Inter"
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    // Count Badge
                    Rectangle {
                        color: md.tertiaryContainer
                        border.color: md.borderTertiary
                        border.width: 1.5
                        radius: 6
                        implicitWidth: 64
                        implicitHeight: 24

                        Text {
                            anchors.centerIn: parent
                            text: spoofer.spoofedCount + " Active"
                            color: md.tertiary
                            font.family: "Inter"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // Close icon button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 6
                        color: closeDialogMouse.containsMouse ? md.surfaceContainerHighest : "transparent"
                        border.color: closeDialogMouse.containsMouse ? md.outlineVariant : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 13
                            color: md.surfaceFg
                        }

                        MouseArea {
                            id: closeDialogMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activeGamesModal.close()
                        }
                    }
                }

                Text {
                    text: "Discord currently detects these games as running via Orby:"
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: md.outlineVariant
                }

                // Active games scrollable list with dedicated scrollbar gutter
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    ListView {
                        id: activeListView
                        anchors.fill: parent
                        anchors.rightMargin: 8
                        spacing: 8
                        model: spoofer.spoofedProcesses
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: ScrollBar {
                            id: dialogScrollBar
                            policy: ScrollBar.AsNeeded
                            anchors.right: parent.right
                            anchors.rightMargin: -6
                            contentItem: Rectangle {
                                implicitWidth: 4
                                radius: 2
                                color: md.outlineVariant
                                opacity: dialogScrollBar.active ? 0.9 : 0.4
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                        }

                        delegate: Rectangle {
                            width: activeListView.width
                            height: 56
                            radius: 8
                            color: md.surfaceContainer
                            border.color: md.outlineVariant
                            border.width: 1.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 10
                                spacing: 10

                                // Initial Icon
                                Rectangle {
                                    width: 32
                                    height: 32
                                    radius: 6
                                    color: md.primaryContainer
                                    border.color: md.primary
                                    border.width: 1.5
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        text: {
                                            let title = getGameTitle(modelData)
                                            return title ? title.charAt(0).toUpperCase() : "?"
                                        }
                                        color: md.primaryContainerFg
                                        font.family: "Inter"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                }

                                // Game Name & Executable
                                ColumnLayout {
                                    spacing: 1
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: getGameTitle(modelData)
                                        color: md.surfaceFg
                                        font.family: "Inter"
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: modelData
                                        color: md.tertiary
                                        font.family: "Inter"
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                // Stop button for single game
                                Button {
                                    id: itemStopBtn
                                    text: "Stop"
                                    font.family: "Inter"
                                    font.weight: Font.Bold
                                    font.pixelSize: 12
                                    Layout.preferredWidth: 68
                                    Layout.preferredHeight: 30
                                    Layout.alignment: Qt.AlignVCenter

                                    background: Rectangle {
                                        radius: 6
                                        color: itemStopBtn.hovered ? "#5C1B1E" : md.errorContainer
                                        border.color: md.borderError
                                        border.width: 1.5
                                    }
                                    contentItem: Text {
                                        text: itemStopBtn.text
                                        color: md.error
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font: itemStopBtn.font
                                    }

                                    onClicked: {
                                        spoofer.stopSpoofingProcess(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: md.outlineVariant
                }

                // Dialog Action Buttons
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: dialogStopAllBtn
                        text: "Stop All"
                        font.family: "Inter"
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 100

                        background: Rectangle {
                            radius: 8
                            color: dialogStopAllBtn.hovered ? "#5C1B1E" : md.errorContainer
                            border.color: md.borderError
                            border.width: 1.5
                        }
                        contentItem: Text {
                            text: dialogStopAllBtn.text
                            color: md.error
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font: dialogStopAllBtn.font
                        }

                        onClicked: {
                            spoofer.stopAllSpoofing()
                            activeGamesModal.close()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        id: dialogCloseBtn
                        text: "Done"
                        font.family: "Inter"
                        font.weight: Font.Bold
                        font.pixelSize: 13
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 90

                        background: Rectangle {
                            radius: 8
                            color: dialogCloseBtn.hovered ? md.primaryContainer : md.surfaceContainerHighest
                            border.color: dialogCloseBtn.hovered ? md.primary : md.outlineVariant
                            border.width: 1.5
                        }
                        contentItem: Text {
                            text: dialogCloseBtn.text
                            color: dialogCloseBtn.hovered ? md.primary : md.surfaceFg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font: dialogCloseBtn.font
                        }

                        onClicked: activeGamesModal.close()
                    }
                }
            }
        }
    }
}
