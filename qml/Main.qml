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
    //  Material Design 3 — Color Tokens
    //  Note: QML treats "on" + uppercase as signal handlers,
    //  so M3 "on*" tokens are renamed to "*Fg" (foreground).
    // ════════════════════════════════════════════════════════════════
    QtObject {
        id: md

        // Primary
        readonly property color primary:              "#D0BCFF"
        readonly property color primaryFg:             "#381E72"
        readonly property color primaryContainer:      "#4F378B"
        readonly property color primaryContainerFg:    "#EADDFF"

        // Secondary
        readonly property color secondary:             "#CCC2DC"
        readonly property color secondaryFg:           "#332D41"
        readonly property color secondaryContainer:    "#4A4458"

        // Tertiary (Teal accent)
        readonly property color tertiary:              "#7DD3C0"
        readonly property color tertiaryContainer:     "#1A3A34"
        readonly property color tertiaryFg:            "#003731"

        // Error
        readonly property color error:                 "#F2B8B5"
        readonly property color errorContainer:        "#8C1D18"

        // Surface system
        readonly property color background:            "#141218"
        readonly property color surface:               "#141218"
        readonly property color surfaceContainer:      "#211F26"
        readonly property color surfaceContainerHigh:  "#2B2930"
        readonly property color surfaceContainerHighest: "#36343B"
        readonly property color surfaceBright:         "#3B383E"

        // Foreground / On-surface
        readonly property color surfaceFg:             "#E6E1E5"
        readonly property color surfaceVariantFg:      "#CAC4D0"
        readonly property color outline:               "#938F99"
        readonly property color outlineVariant:        "#49454F"
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
        anchors.margins: 20
        spacing: 16

        // ── Top App Bar ──
        ColumnLayout {
            spacing: 4
            Layout.bottomMargin: 4

            Text {
                text: "Orby"
                color: md.surfaceFg
                font.family: "Inter"
                font.pixelSize: 30
                font.weight: Font.Bold
                font.letterSpacing: -0.8
            }
            Text {
                text: "Discord Game Presence Spoofer"
                color: md.surfaceVariantFg
                font.family: "Inter"
                font.pixelSize: 14
                font.weight: Font.Normal
            }
        }

        // ── Status Card ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            radius: 20
            color: spoofer.isSpoofing ? md.tertiaryContainer : md.surfaceContainer
            border.color: spoofer.isSpoofing ? md.tertiary : md.outlineVariant
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: 350; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 350; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                anchors.topMargin: 12
                anchors.bottomMargin: 12

                // Pulsing status dot
                Rectangle {
                    width: 10; height: 10
                    radius: 5
                    color: spoofer.isSpoofing ? md.tertiary : md.outline
                    Layout.alignment: Qt.AlignVCenter

                    SequentialAnimation on opacity {
                        running: spoofer.isSpoofing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                    }

                    // Reset opacity when not spoofing
                    Behavior on color {
                        ColorAnimation { duration: 250 }
                    }

                    // Ensure full opacity when not animating
                    Component.onCompleted: opacity = 1.0
                    onColorChanged: if (!spoofer.isSpoofing) opacity = 1.0
                }

                // Status text
                ColumnLayout {
                    spacing: 2
                    Layout.leftMargin: 12
                    Layout.fillWidth: true

                    Text {
                        text: spoofer.isSpoofing ? "CURRENTLY SPOOFING" : "INACTIVE"
                        color: spoofer.isSpoofing ? md.tertiary : md.outline
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.2

                        Behavior on color {
                            ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
                        }
                    }
                    Text {
                        text: spoofer.isSpoofing ? spoofer.currentProcessName : "Select a game to begin"
                        color: md.surfaceFg
                        font.family: "Inter"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Stop pill button
                Button {
                    visible: spoofer.isSpoofing
                    text: "Stop"
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    font.pixelSize: 13
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter

                    background: Rectangle {
                        radius: 18
                        color: parent.hovered ? "#5C1B1E" : md.errorContainer
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: md.error
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font: parent.font
                    }

                    onClicked: spoofer.stopSpoofing()
                }
            }
        }

        // ── Search Bar (M3 fully rounded) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 28
            color: md.surfaceContainerHigh
            border.color: searchInput.activeFocus ? md.primary : "transparent"
            border.width: searchInput.activeFocus ? 2 : 0

            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12

                // Search icon
                Text {
                    text: "\u{1F50D}"
                    font.pixelSize: 16
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
                    font.pixelSize: 15
                    selectionColor: md.primary
                    selectedTextColor: md.primaryFg
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search games..."
                        color: md.outline
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                        visible: !parent.text && !parent.activeFocus
                    }

                    onTextChanged: updateFilter()
                }

                // Clear button
                Text {
                    text: "✕"
                    font.pixelSize: 14
                    color: md.surfaceVariantFg
                    visible: searchInput.text.length > 0
                    Layout.alignment: Qt.AlignVCenter

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            searchInput.text = ""
                            searchInput.focus = false
                        }
                    }
                }
            }
        }

        // ── Game count label ──
        Text {
            text: {
                if (discordApi.isLoading) return "Loading..."
                let total = gameListView.count
                return total + " game" + (total !== 1 ? "s" : "") + (searchInput.text ? " found" : " available")
            }
            color: md.outline
            font.family: "Inter"
            font.pixelSize: 12
            font.weight: Font.Medium
            Layout.leftMargin: 4
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
                spacing: 6
                model: filteredGames
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 400
                reuseItems: true

                // Custom thin scrollbar
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: md.outlineVariant
                        opacity: parent.active ? 0.8 : 0.0
                        Behavior on opacity {
                            NumberAnimation { duration: 300 }
                        }
                    }
                }

                delegate: Rectangle {
                    id: gameTile
                    width: ListView.view.width
                    height: 68
                    radius: 16
                    color: tileMouseArea.containsMouse ? md.surfaceContainerHigh : md.surfaceContainer
                    border.color: tileMouseArea.containsMouse ? md.outlineVariant : "transparent"
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    Behavior on border.color {
                        ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 12
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10

                        // Game icon placeholder — first letter
                        Rectangle {
                            width: 42; height: 42
                            radius: 12
                            color: md.primaryContainer
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                color: md.primaryContainerFg
                                font.family: "Inter"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                            }
                        }

                        // Game info
                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true
                            Layout.leftMargin: 12

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
                                color: md.outline
                                font.family: "Inter"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Spoof / Active button
                        Button {
                            id: spoofBtn
                            property bool isActive: spoofer.currentProcessName === modelData.primaryExecutable && spoofer.isSpoofing

                            text: isActive ? "Active" : "Spoof"
                            enabled: !isActive
                            font.family: "Inter"
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter

                            background: Rectangle {
                                radius: 18
                                color: {
                                    if (spoofBtn.isActive)
                                        return md.tertiaryContainer
                                    if (spoofBtn.hovered)
                                        return md.primaryContainer
                                    return md.surfaceContainerHighest
                                }
                                border.color: {
                                    if (spoofBtn.isActive)
                                        return md.tertiary
                                    if (spoofBtn.hovered)
                                        return md.primary
                                    return md.outlineVariant
                                }
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                Behavior on border.color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }

                            contentItem: Text {
                                text: spoofBtn.text
                                color: {
                                    if (spoofBtn.isActive)
                                        return md.tertiary
                                    if (spoofBtn.hovered)
                                        return md.primary
                                    return md.surfaceVariantFg
                                }
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: spoofBtn.font

                                Behavior on color {
                                    ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                            }

                            onClicked: {
                                spoofer.startSpoofing(modelData.primaryExecutable)
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
                spacing: 16
                visible: discordApi.isLoading

                // Spinning indicator
                Rectangle {
                    width: 32; height: 32
                    radius: 16
                    color: "transparent"
                    border.color: md.primary
                    border.width: 3
                    Layout.alignment: Qt.AlignHCenter

                    // Clip to show partial arc
                    Rectangle {
                        width: 16; height: 16
                        color: md.background
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: discordApi.isLoading
                    }
                }

                Text {
                    text: "Fetching games from Discord..."
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 14
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
                    font.pixelSize: 36
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: searchInput.text ? "No games match your search" : "No games available"
                    color: md.surfaceVariantFg
                    font.family: "Inter"
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
