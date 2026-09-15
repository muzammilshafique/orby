import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import Orby 1.0

Window {
    id: window
    width: 480
    height: 720
    minimumWidth: 420
    minimumHeight: 580
    visible: true
    title: "Orby — Discord Game Presence Spoofer"
    color: md.surface

    onClosing: function(close) {
        if (typeof spoofer !== "undefined" && spoofer.isSpoofing && typeof trayManager !== "undefined" && trayManager.closeToTray && trayManager.isSystemTrayAvailable) {
            close.accepted = false
            window.hide()

            let summary = ""
            if (spoofer.spoofedProcesses && spoofer.spoofedProcesses.length > 0) {
                let titles = []
                for (let i = 0; i < spoofer.spoofedProcesses.length; i++) {
                    titles.push(getGameTitle(spoofer.spoofedProcesses[i]))
                }
                if (titles.length === 1) {
                    summary = titles[0]
                } else if (titles.length === 2) {
                    summary = titles[0] + " & " + titles[1]
                } else {
                    summary = titles[0] + ", " + titles[1] + " (+" + (titles.length - 2) + " more)"
                }
            }
            trayManager.notifyClosedToTray(summary)
        } else {
            close.accepted = true
            if (typeof spoofer !== "undefined") {
                spoofer.stopAllSpoofing()
            }
            Qt.quit()
        }
    }

    Connections {
        target: (typeof trayManager !== "undefined") ? trayManager : null
        function onShowWindowRequested() {
            window.show()
            window.raise()
            window.requestActivate()
        }
        function onHideWindowRequested() {
            window.hide()
        }
        function onToggleWindowRequested() {
            if (window.visible) {
                window.hide()
            } else {
                window.show()
                window.raise()
                window.requestActivate()
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Google Material 3 (Material You) Design System Tokens
    // ════════════════════════════════════════════════════════════════
    QtObject {
        id: md

        // Typography
        readonly property string fontFamily: "Google Sans Flex"
        readonly property string iconFont:   "Material Symbols Rounded"

        // Primary Accent (Material 3 Dynamic Blue)
        readonly property color primary:                "#A8C7FA"
        readonly property color primaryFg:              "#062E6F"
        readonly property color primaryContainer:        "#1E3A68"
        readonly property color primaryContainerFg:      "#D3E3FD"

        // Secondary Accent (Material Cyan)
        readonly property color secondary:              "#7FCFFF"
        readonly property color secondaryFg:            "#003549"
        readonly property color secondaryContainer:      "#004D68"
        readonly property color secondaryContainerFg:    "#C2E7FF"

        // Tertiary Accent (Material Emerald / Active Mint)
        readonly property color tertiary:               "#6DD58C"
        readonly property color tertiaryFg:             "#0A3818"
        readonly property color tertiaryContainer:       "#123B22"
        readonly property color tertiaryContainerFg:     "#C4EED0"

        // Error Tonal (Material Coral Red)
        readonly property color error:                  "#FFB4AB"
        readonly property color errorFg:                "#690005"
        readonly property color errorContainer:          "#4D1418"
        readonly property color errorContainerFg:        "#FFDAD6"

        // Dark Surface Hierarchy (Android 14/15 Tonal Levels)
        readonly property color surface:                "#0E1015"
        readonly property color surfaceDim:             "#0A0C0F"
        readonly property color surfaceBright:          "#2D3139"
        readonly property color surfaceContainerLowest: "#08090C"
        readonly property color surfaceContainerLow:    "#13161C"
        readonly property color surfaceContainer:       "#191D24"
        readonly property color surfaceContainerHigh:   "#21252E"
        readonly property color surfaceContainerHighest:"#2B303B"

        // Outlines & Borders
        readonly property color outline:                "#8A909D"
        readonly property color outlineVariant:         "#3A3F4B"
        readonly property color outlineSubtle:          "#262A33"

        // Foreground Content
        readonly property color surfaceFg:              "#E6E8EE"
        readonly property color surfaceVariantFg:       "#B0B5C2"
        readonly property color surfaceSubtleFg:        "#787E8C"
    }

    // ════════════════════════════════════════════════════════════════
    //  Reusable Material Symbols Rounded Icon Component
    // ════════════════════════════════════════════════════════════════
    component MaterialIcon: Text {
        id: iconRoot
        property string name: ""
        property int size: 20
        property color iconColor: md.surfaceVariantFg
        property bool filled: false

        width: size
        height: size
        text: {
            switch(name) {
                case "search":            return "\uE8B6";
                case "close":             return "\uE5CD";
                case "sports_esports":    return "\uEA28";
                case "play_arrow":        return "\uE037";
                case "stop":              return "\uE047";
                case "refresh":           return "\uE5D5";
                case "check":             return "\uE5CA";
                case "check_circle":      return "\uF0BE";
                case "layers":            return "\uE53B";
                case "tune":              return "\uE429";
                case "info":              return "\uE88E";
                case "bolt":              return "\uEA0B";
                case "delete":            return "\uE92E";
                case "expand_more":       return "\uE5CF";
                case "arrow_forward":     return "\uE5C8";
                case "terminal":          return "\uEB8E";
                case "filter_list":       return "\uE152";
                case "shield":            return "\uE9E0";
                case "power_settings_new":return "\uF8C7";
                case "help":              return "\uE8FD";
                case "settings":          return "\uE8B8";
                case "fiber_manual_record":return "\uE061";
                default:                  return name;
            }
        }
        font.family: md.iconFont
        font.pixelSize: size
        font.variableAxes: { "FILL": filled ? 1.0 : 0.0 }
        color: iconColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        renderType: Text.QtRendering
        antialiasing: true
    }

    // ════════════════════════════════════════════════════════════════
    //  Backend Instances
    // ════════════════════════════════════════════════════════════════
    DiscordApi {
        id: discordApi
        Component.onCompleted: fetchGames()
        onErrorOccurred: (msg) => console.warn("[DiscordApi]", msg)
    }

    ProcessSpoofer {
        id: spoofer
        onErrorOccurred: (msg) => console.warn("[Spoofer]", msg)
        onSpoofedProcessesChanged: {
            if (typeof trayManager !== "undefined") {
                if (spoofer.isSpoofing && spoofer.spoofedProcesses.length > 0) {
                    let titles = []
                    for (let i = 0; i < spoofer.spoofedProcesses.length; i++) {
                        titles.push(getGameTitle(spoofer.spoofedProcesses[i]))
                    }
                    trayManager.setTrayToolTip("Orby — Spoofing: " + titles.join(", "))
                } else {
                    trayManager.setTrayToolTip("Orby — Discord Game Presence Spoofer")
                }
            }
        }
    }

    // Smooth refresh animation timer so users enjoy a sleek lazy-loading wave
    Timer {
        id: refreshDelayTimer
        interval: 650
        repeat: false
    }

    readonly property bool isRefreshingOrLoading: discordApi.isLoading || refreshDelayTimer.running

    function getGameTitle(execName) {
        if (!discordApi || !discordApi.games) return execName
        let match = discordApi.games.find(g => g.primaryExecutable === execName)
        return match ? match.name : execName
    }

    // ════════════════════════════════════════════════════════════════
    //  Filter & Search State
    // ════════════════════════════════════════════════════════════════
    property var filteredGames: []
    property string activeFilter: "all" // "all", "active", "popular"

    readonly property var popularKeywords: [
        "fortnite", "valorant", "genshin", "honkai", "warframe", "apex", 
        "overwatch", "roblox", "minecraft", "destiny", "rocket league", "pubg", 
        "league of legends", "dota", "counter-strike", "call of duty", "gta"
    ]

    function updateFilter() {
        let query = searchInput.text.toLowerCase().trim()
        let games = discordApi.games || []

        if (activeFilter === "active") {
            games = games.filter(g => spoofer.isSpoofingProcess(g.primaryExecutable))
        } else if (activeFilter === "popular") {
            games = games.filter(g => {
                let lower = g.name.toLowerCase()
                return popularKeywords.some(kw => lower.includes(kw))
            })
        }

        if (query !== "") {
            games = games.filter(g => 
                g.name.toLowerCase().includes(query) || 
                (g.primaryExecutable && g.primaryExecutable.toLowerCase().includes(query))
            )
        }

        filteredGames = games
        gameListView.model = filteredGames
    }

    Connections {
        target: discordApi
        function onGamesChanged() { updateFilter() }
    }

    Connections {
        target: spoofer
        function onSpoofedProcessesChanged() {
            if (activeFilter === "active") updateFilter()
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Main Layout
    // ════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 16

        // ── 1. Top App Bar ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // App Icon Squircle
            Rectangle {
                width: 44
                height: 44
                radius: 14
                color: md.surfaceContainerHigh
                border.color: md.outlineVariant
                border.width: 1
                Layout.alignment: Qt.AlignVCenter

                Image {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    source: "qrc:/icons/orby.png"
                    smooth: true
                    mipmap: true
                }
            }

            ColumnLayout {
                spacing: 2
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: 8
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "Orby"
                        color: md.surfaceFg
                        font.family: md.fontFamily
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        font.letterSpacing: -0.4
                        verticalAlignment: Text.AlignVCenter
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // OS Platform Chip (Centered with exact 7px top / 7px bottom balance)
                    Rectangle {
                        color: md.primaryContainer
                        radius: 100
                        implicitWidth: osText.implicitWidth + 18
                        implicitHeight: 21
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            id: osText
                            anchors.centerIn: parent
                            text: Qt.platform.os === "windows" ? "WINDOWS" : "LINUX"
                            color: md.primaryContainerFg
                            font.family: md.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 0.6
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Text {
                    text: "Discord Game Presence Spoofer"
                    color: md.surfaceVariantFg
                    font.family: md.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Spring spacer pushing refresh button to the far right corner
            Item { Layout.fillWidth: true }

            // Reload / Refresh Library Button (Top Right Corner)
            Rectangle {
                id: refreshBtn
                width: 38
                height: 38
                radius: 19
                color: refreshMouse.containsPress ? md.surfaceContainerHighest : (refreshMouse.containsMouse ? md.surfaceContainerHigh : "transparent")
                border.color: refreshMouse.containsMouse ? md.outlineVariant : "transparent"
                border.width: 1
                Layout.alignment: Qt.AlignTop | Qt.AlignRight

                MaterialIcon {
                    id: refreshIcon
                    anchors.centerIn: parent
                    name: "refresh"
                    size: 20
                    iconColor: refreshMouse.containsMouse ? md.primary : md.surfaceVariantFg
                    renderType: Text.QtRendering
                    antialiasing: true
                    layer.enabled: isRefreshingOrLoading
                    layer.smooth: true

                    RotationAnimator on rotation {
                        running: isRefreshingOrLoading
                        from: 0; to: 360
                        duration: 750
                        loops: Animation.Infinite
                    }
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        refreshDelayTimer.restart()
                        discordApi.fetchGames()
                    }
                }

                ToolTip.visible: refreshMouse.containsMouse
                ToolTip.text: "Refresh Games List"
                ToolTip.delay: 400
            }
        }

        // ── 2. Material 3 Hero Status Banner ──
        Rectangle {
            id: statusBanner
            Layout.fillWidth: true
            Layout.preferredHeight: spoofer.isSpoofing ? 86 : 74
            radius: 22
            color: spoofer.isSpoofing ? md.tertiaryContainer : md.surfaceContainer
            border.color: {
                if (spoofer.isSpoofing) {
                    return bannerMouse.containsMouse ? md.secondary : md.tertiary
                }
                return bannerMouse.containsMouse ? md.outline : md.outlineVariant
            }
            border.width: spoofer.isSpoofing ? 1.8 : 1

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            MouseArea {
                id: bannerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: spoofer.isSpoofing ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (spoofer.isSpoofing) activeGamesModal.open()
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 20
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: 12

                // Leading Status Icon with Radar / Glow Effect
                Item {
                    width: 44
                    height: 44
                    Layout.alignment: Qt.AlignVCenter

                    // Pulsing radar glow when active
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 6
                        height: parent.height + 6
                        radius: width / 2
                        color: md.tertiary
                        opacity: 0.15
                        visible: spoofer.isSpoofing

                        SequentialAnimation on scale {
                            running: spoofer.isSpoofing
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.85; to: 1.25; duration: 1200; easing.type: Easing.OutQuad }
                            NumberAnimation { from: 1.25; to: 0.85; duration: 1200; easing.type: Easing.InQuad }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: spoofer.isSpoofing ? md.tertiary : md.surfaceContainerHigh
                        border.color: spoofer.isSpoofing ? md.tertiary : md.outlineVariant
                        border.width: 1

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: spoofer.isSpoofing ? "bolt" : "sports_esports"
                            size: 24
                            iconColor: spoofer.isSpoofing ? md.tertiaryFg : md.surfaceVariantFg
                        }
                    }
                }

                // Status Texts
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: {
                                if (!spoofer.isSpoofing) return "SYSTEM READY"
                                let count = spoofer.spoofedCount
                                return "SPOOFING ACTIVE (" + count + " " + (count === 1 ? "GAME" : "GAMES") + ")"
                            }
                            color: spoofer.isSpoofing ? md.tertiary : md.surfaceSubtleFg
                            font.family: md.fontFamily
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            verticalAlignment: Text.AlignVCenter
                            Layout.alignment: Qt.AlignVCenter
                        }

                        // Modal trigger badge
                        Rectangle {
                            visible: spoofer.isSpoofing
                            color: md.surfaceContainerHighest
                            radius: 100
                            implicitWidth: badgeRow.implicitWidth + 14
                            implicitHeight: 20
                            Layout.alignment: Qt.AlignVCenter

                            Row {
                                id: badgeRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    text: "View"
                                    color: md.surfaceFg
                                    font.family: md.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 1
                                }
                                MaterialIcon {
                                    name: "arrow_forward"
                                    size: 11
                                    iconColor: md.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: 1
                                }
                            }
                        }
                    }

                    Text {
                        text: {
                            if (!spoofer.isSpoofing) return "Select a game to spoof its background process"
                            let count = spoofer.spoofedCount
                            if (count === 1) {
                                return getGameTitle(spoofer.spoofedProcesses[0])
                            }
                            return count + " games currently running in background"
                        }
                        color: md.surfaceFg
                        font.family: md.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                    }
                }

                // Stop All Button (Pill Action - Strictly Centered with Corner Clearance)
                Rectangle {
                    id: stopAllBtn
                    visible: spoofer.isSpoofing
                    Layout.preferredWidth: 92
                    Layout.preferredHeight: 34
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                    Layout.rightMargin: 6
                    radius: 100
                    color: stopAllMouse.containsPress ? "#4D1115" : (stopAllMouse.containsMouse ? "#63171B" : md.errorContainer)
                    border.color: stopAllMouse.containsMouse ? md.error : md.errorContainer
                    border.width: 1

                    scale: stopAllMouse.containsPress ? 0.94 : (stopAllMouse.containsMouse ? 1.02 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 2
                            color: md.errorContainerFg
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Stop All"
                            color: md.errorContainerFg
                            font.family: md.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: stopAllMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: spoofer.stopAllSpoofing()
                    }
                }
            }
        }

        // ── 3. Material 3 Android Pill Search Bar ──
        Rectangle {
            id: searchBarBox
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            radius: 26
            color: md.surfaceContainerHigh
            border.color: searchInput.activeFocus ? md.primary : md.outlineVariant
            border.width: searchInput.activeFocus ? 2 : 1

            Behavior on border.color {
                ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 14
                spacing: 12

                MaterialIcon {
                    name: "search"
                    size: 22
                    iconColor: searchInput.activeFocus ? md.primary : md.surfaceVariantFg
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: TextInput.AlignVCenter
                    color: md.surfaceFg
                    font.family: md.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    selectionColor: md.primaryContainer
                    selectedTextColor: md.primaryContainerFg
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.fill: parent
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Search games or executables..."
                        color: md.surfaceSubtleFg
                        font: parent.font
                        verticalAlignment: Text.AlignVCenter
                        visible: !parent.text && !parent.activeFocus
                    }

                    onTextChanged: updateFilter()
                }

                // Clear Search Button
                Rectangle {
                    visible: searchInput.text.length > 0
                    width: 28
                    height: 28
                    radius: 14
                    color: clearMouse.containsMouse ? md.surfaceContainerHighest : "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 16
                        iconColor: md.surfaceFg
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

        // ── 4. Material 3 Fluid Segmented Pill Bar (Compact & Responsive) ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                id: fluidPillTrack
                implicitHeight: 38
                implicitWidth: pillRow.implicitWidth + 8
                radius: 100
                color: md.surfaceContainer
                border.color: md.outlineSubtle
                border.width: 1

                // Animated Fluid Indicator Capsule
                Rectangle {
                    id: fluidIndicator
                    y: pillRow.y
                    height: pillRow.height
                    radius: 100
                    color: md.primaryContainer
                    border.color: md.primary
                    border.width: 1.2
                    z: 1

                    // Target dynamic coordinates aligned to pillRow offset
                    x: {
                        if (activeFilter === "all") return pillRow.x + pillAll.x
                        if (activeFilter === "active") return pillRow.x + pillActive.x
                        if (activeFilter === "popular") return pillRow.x + pillPopular.x
                        return pillRow.x + pillAll.x
                    }
                    width: {
                        if (activeFilter === "all") return pillAll.width
                        if (activeFilter === "active") return pillActive.width
                        if (activeFilter === "popular") return pillPopular.width
                        return pillAll.width
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 260
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: pillRow
                    anchors.centerIn: parent
                    spacing: 6
                    z: 2

                    // Fluid Pill Item Component (Compact, responsive Android M3 style)
                    component FluidPill: Item {
                        id: fPill
                        property string filterKey: ""
                        property string label: ""
                        property string iconName: ""
                        property int badgeCount: 0
                        property bool isSelected: activeFilter === filterKey

                        implicitHeight: 32
                        implicitWidth: fPillContent.implicitWidth + 24

                        // Subtle hover tint on unselected pills
                        Rectangle {
                            anchors.fill: parent
                            radius: 100
                            color: fMouse.containsMouse && !fPill.isSelected ? md.surfaceContainerHigh : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Row {
                            id: fPillContent
                            anchors.centerIn: parent
                            spacing: 6

                            MaterialIcon {
                                visible: fPill.iconName !== ""
                                name: fPill.isSelected ? "check" : fPill.iconName
                                size: 15
                                iconColor: fPill.isSelected ? md.primary : md.surfaceVariantFg
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on iconColor { ColorAnimation { duration: 200 } }
                            }

                            Text {
                                text: fPill.label
                                color: fPill.isSelected ? md.primaryContainerFg : md.surfaceVariantFg
                                font.family: md.fontFamily
                                font.pixelSize: 12
                                font.weight: fPill.isSelected ? Font.Bold : Font.Medium
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }

                            Rectangle {
                                visible: fPill.badgeCount > 0
                                radius: 10
                                implicitHeight: 18
                                implicitWidth: fBadgeText.implicitWidth + 10
                                color: fPill.isSelected ? md.primary : md.surfaceContainerHigh
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 200 } }

                                Text {
                                    id: fBadgeText
                                    anchors.centerIn: parent
                                    text: fPill.badgeCount > 999 ? "999+" : fPill.badgeCount
                                    color: fPill.isSelected ? md.primaryFg : md.surfaceSubtleFg
                                    font.family: md.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    verticalAlignment: Text.AlignVCenter
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                        }

                        MouseArea {
                            id: fMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                activeFilter = fPill.filterKey
                                updateFilter()
                            }
                        }
                    }

                    FluidPill {
                        id: pillAll
                        filterKey: "all"
                        label: "All Games"
                        iconName: "sports_esports"
                        // Badge removed as requested (no 999+ clutter)
                    }

                    FluidPill {
                        id: pillActive
                        filterKey: "active"
                        label: "Active"
                        iconName: "bolt"
                        badgeCount: spoofer.spoofedCount
                    }

                    FluidPill {
                        id: pillPopular
                        filterKey: "popular"
                        label: "Popular"
                        iconName: "tune"
                    }
                }
            }

            Item { Layout.fillWidth: true }

            Text {
                text: {
                    if (isRefreshingOrLoading) return "Refreshing..."
                    return gameListView.count + " shown"
                }
                color: md.surfaceSubtleFg
                font.family: md.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // ── 5. Games List View Container ──
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // ── Skeleton Lazy Loading List (Visible when isRefreshingOrLoading) ──
            ColumnLayout {
                id: skeletonView
                anchors.fill: parent
                spacing: 10
                visible: opacity > 0.0
                opacity: isRefreshingOrLoading ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                Repeater {
                    model: 7
                    Rectangle {
                        id: skeletonCard
                        Layout.fillWidth: true
                        height: 72
                        radius: 18
                        color: md.surfaceContainer
                        border.color: md.outlineSubtle
                        border.width: 1

                        // Staggered cascade wave shimmer animation
                        SequentialAnimation on opacity {
                            running: isRefreshingOrLoading
                            loops: Animation.Infinite
                            PauseAnimation { duration: index * 90 }
                            NumberAnimation { from: 0.35; to: 0.95; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.95; to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 14
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 14

                            // Skeleton Avatar
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 14
                                color: md.surfaceContainerHighest
                                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                            }

                            // Skeleton Title & Subtitle lines
                            ColumnLayout {
                                spacing: 8
                                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                                Rectangle {
                                    height: 14
                                    radius: 7
                                    color: md.surfaceContainerHighest
                                    width: [160, 200, 140, 180, 150, 190, 140][index % 7]
                                }

                                Rectangle {
                                    height: 10
                                    radius: 5
                                    color: md.surfaceContainerHigh
                                    width: [100, 130, 90, 120, 100, 125, 95][index % 7]
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Skeleton Button Pill (Exact match with real actionBtn)
                            Rectangle {
                                Layout.preferredWidth: 86
                                Layout.preferredHeight: 36
                                radius: 100
                                color: md.surfaceContainerHigh
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ── Actual Game List View (Smoothly fades in when loaded) ──
            ListView {
                id: gameListView
                anchors.fill: parent
                anchors.rightMargin: 4
                spacing: 10
                model: filteredGames
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 600
                reuseItems: true
                visible: opacity > 0.0
                opacity: isRefreshingOrLoading ? 0.0 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                ScrollBar.vertical: ScrollBar {
                    id: m3ScrollBar
                    policy: ScrollBar.AsNeeded
                    anchors.right: parent.right
                    anchors.rightMargin: -4
                    contentItem: Rectangle {
                        implicitWidth: 5
                        radius: 3
                        color: md.outlineVariant
                        opacity: m3ScrollBar.active ? 0.8 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                delegate: Rectangle {
                    id: gameTile
                    width: gameListView.width
                    height: 72
                    radius: 18

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
                        if (gameTile.isThisActive) return md.tertiary
                        if (tileMouseArea.containsMouse) return md.primary
                        return md.outlineSubtle
                    }
                    border.width: gameTile.isThisActive ? 1.8 : 1

                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 14

                        // Game Squircle Avatar
                        Rectangle {
                            width: 44
                            height: 44
                            radius: 14
                            color: gameTile.isThisActive ? md.tertiary : md.surfaceContainerHigh
                            border.color: gameTile.isThisActive ? md.tertiary : md.outlineVariant
                            border.width: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: 1
                                text: modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                color: gameTile.isThisActive ? md.tertiaryFg : md.primary
                                font.family: md.fontFamily
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        // Game Details Column
                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                spacing: 8
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: modelData.name
                                    color: md.surfaceFg
                                    font.family: md.fontFamily
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.maximumWidth: Math.max(0, gameTile.width - 188 - (gameTile.isThisActive ? (activePill.implicitWidth + 8) : 0))
                                }

                                // Active Tag Pill (placed directly beside title, vertically centered)
                                Rectangle {
                                    id: activePill
                                    visible: gameTile.isThisActive
                                    color: md.tertiary
                                    radius: 100
                                    implicitWidth: activePillText.implicitWidth + 14
                                    implicitHeight: 20
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: activePillText
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: 1 // Optical alignment
                                        text: "SPOOFING"
                                        color: md.tertiaryFg
                                        font.family: md.fontFamily
                                        font.pixelSize: 9
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.5
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            RowLayout {
                                spacing: 6
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                Layout.alignment: Qt.AlignVCenter

                                MaterialIcon {
                                    name: "terminal"
                                    size: 13
                                    iconColor: gameTile.isThisActive ? md.tertiary : md.surfaceSubtleFg
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: modelData.primaryExecutable
                                    color: gameTile.isThisActive ? md.tertiaryContainerFg : md.surfaceSubtleFg
                                    font.family: md.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                }
                            }
                        }

                        // Pill Action Button (Spoof / Stop) with strict horizontal, vertical, and optical centering
                        Rectangle {
                            id: actionBtn
                            Layout.preferredWidth: 86
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            radius: 100
                            color: {
                                if (gameTile.isThisActive) {
                                    return actionMouse.containsMouse ? "#69171C" : md.errorContainer
                                }
                                if (actionMouse.containsMouse) return md.primary
                                return md.primaryContainer
                            }
                            border.color: {
                                if (gameTile.isThisActive) return md.error
                                return md.primary
                            }
                            border.width: 1

                            scale: actionMouse.containsPress ? 0.94 : (actionMouse.containsMouse ? 1.03 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 100 } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                // Vector Icon Container
                                Item {
                                    width: 14
                                    height: 14
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Solid rounded Stop square
                                    Rectangle {
                                        visible: gameTile.isThisActive
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        radius: 2
                                        color: md.errorContainerFg
                                    }

                                    // Crisp vector Play triangle (prominent, filled, and rounded)
                                    Canvas {
                                        visible: !gameTile.isThisActive
                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: 0.5
                                        width: 14
                                        height: 14
                                        antialiasing: true
                                        property color iconColor: actionMouse.containsMouse ? md.primaryFg : md.primaryContainerFg
                                        onIconColorChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            
                                            // Smooth rounded corners via lineJoin
                                            ctx.lineJoin = "round";
                                            ctx.lineWidth = 3; 
                                            ctx.fillStyle = iconColor;
                                            ctx.strokeStyle = iconColor;
                                            
                                            ctx.beginPath();
                                            // Vertices for the triangle (inset by radius)
                                            ctx.moveTo(3.0, 2.5);
                                            ctx.lineTo(11.0, 7.0);
                                            ctx.lineTo(3.0, 11.5);
                                            ctx.closePath();
                                            
                                            ctx.fill();
                                            ctx.stroke();
                                        }
                                    }
                                }

                                Text {
                                    text: gameTile.isThisActive ? "Stop" : "Spoof"
                                    color: {
                                        if (gameTile.isThisActive) return md.errorContainerFg
                                        if (actionMouse.containsMouse) return md.primaryFg
                                        return md.primaryContainerFg
                                    }
                                    font.family: md.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: actionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (gameTile.isThisActive) {
                                        spoofer.stopSpoofingProcess(modelData.primaryExecutable)
                                    } else {
                                        spoofer.startSpoofing(modelData.primaryExecutable,
                                                              modelData.name,
                                                              modelData.steamAppId ?? "",
                                                              modelData.id ?? "")
                                    }
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

            // Empty State (When not loading and 0 results)
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: !isRefreshingOrLoading && gameListView.count === 0

                Rectangle {
                    width: 56
                    height: 56
                    radius: 28
                    color: md.surfaceContainerHigh
                    Layout.alignment: Qt.AlignHCenter

                    MaterialIcon {
                        anchors.centerIn: parent
                        name: "sports_esports"
                        size: 30
                        iconColor: md.surfaceSubtleFg
                    }
                }

                Text {
                    text: searchInput.text ? "No games found matching '" + searchInput.text + "'" : "No games available"
                    color: md.surfaceVariantFg
                    font.family: md.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════
    //  Active Spoofed Games Modal (Material 3 Bottom Sheet Style)
    // ════════════════════════════════════════════════════════════════
    Rectangle {
        id: activeGamesModal
        anchors.fill: parent
        color: "#99000000"
        visible: false
        z: 999
        opacity: visible ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        function open() {
            visible = true
        }

        function close() {
            visible = false
        }

        MouseArea {
            anchors.fill: parent
            onClicked: activeGamesModal.close()
        }

        Connections {
            target: spoofer
            function onSpoofedProcessesChanged() {
                if (!spoofer.isSpoofing && activeGamesModal.visible) {
                    activeGamesModal.close()
                }
            }
        }

        // Bottom Sheet Container
        Rectangle {
            id: dialogBox
            width: Math.min(parent.width - 32, 430)
            height: Math.min(parent.height - 80, 480)
            anchors.centerIn: parent
            radius: 24
            color: md.surfaceContainerHigh
            border.color: md.outlineVariant
            border.width: 1.5
            clip: true

            MouseArea {
                anchors.fill: parent
                onClicked: {} // Prevent dismiss on click inside
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 16
                anchors.bottomMargin: 18
                spacing: 14

                // Drag Handle
                Rectangle {
                    width: 36
                    height: 4
                    radius: 2
                    color: md.outlineVariant
                    Layout.alignment: Qt.AlignHCenter
                }

                // Dialog Header
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 12
                        color: md.tertiaryContainer
                        border.color: md.tertiary
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "bolt"
                            size: 20
                            iconColor: md.tertiary
                        }
                    }

                    ColumnLayout {
                        spacing: 3
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter

                        RowLayout {
                            spacing: 8
                            Layout.fillWidth: true

                            Text {
                                text: "Active Games"
                                color: md.surfaceFg
                                font.family: md.fontFamily
                                font.pixelSize: 17
                                font.weight: Font.Bold
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }

                            // Count Badge placed directly beside title
                            Rectangle {
                                color: md.tertiaryContainer
                                border.color: md.tertiary
                                border.width: 1
                                radius: 100
                                implicitWidth: countBadgeText.implicitWidth + 12
                                implicitHeight: 20
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    id: countBadgeText
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: 1
                                    text: spoofer.spoofedCount + " Running"
                                    color: md.tertiary
                                    font.family: md.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            text: "Discord recognizes these titles as currently playing"
                            color: md.surfaceVariantFg
                            font.family: md.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Close Button
                    Rectangle {
                        width: 30
                        height: 30
                        radius: 15
                        color: closeDialogMouse.containsMouse ? md.surfaceContainerHighest : "transparent"
                        Layout.alignment: Qt.AlignVCenter

                        MaterialIcon {
                            anchors.centerIn: parent
                            name: "close"
                            size: 16
                            iconColor: md.surfaceFg
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

                // Divider
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: md.outlineSubtle
                }

                // Active List
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: activeListView
                        anchors.fill: parent
                        spacing: 8
                        model: spoofer.spoofedProcesses
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            width: activeListView.width
                            height: 56
                            radius: 14
                            color: md.surfaceContainer
                            border.color: md.outlineVariant
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Rectangle {
                                    width: 34
                                    height: 34
                                    radius: 10
                                    color: md.tertiaryContainer
                                    border.color: md.tertiary
                                    border.width: 1
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: 1
                                        text: {
                                            let title = getGameTitle(modelData)
                                            return title ? title.charAt(0).toUpperCase() : "?"
                                        }
                                        color: md.tertiary
                                        font.family: md.fontFamily
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                ColumnLayout {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: getGameTitle(modelData)
                                        color: md.surfaceFg
                                        font.family: md.fontFamily
                                        font.pixelSize: 13
                                        font.weight: Font.Bold
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                    }
                                    Text {
                                        text: modelData
                                        color: md.tertiary
                                        font.family: md.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                    }
                                }

                                Rectangle {
                                    id: itemStopBtn
                                    Layout.preferredWidth: 74
                                    Layout.preferredHeight: 32
                                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                    radius: 100
                                    color: itemStopMouse.containsPress ? "#4D1115" : (itemStopMouse.containsMouse ? "#63171B" : md.errorContainer)
                                    border.color: md.error
                                    border.width: 1

                                    scale: itemStopMouse.containsPress ? 0.94 : (itemStopMouse.containsMouse ? 1.03 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Rectangle {
                                            width: 9
                                            height: 9
                                            radius: 2
                                            color: md.errorContainerFg
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: "Stop"
                                            color: md.errorContainerFg
                                            font.family: md.fontFamily
                                            font.weight: Font.Bold
                                            font.pixelSize: 11
                                            verticalAlignment: Text.AlignVCenter
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: itemStopMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: spoofer.stopSpoofingProcess(modelData)
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
                    color: md.outlineSubtle
                }

                // Action Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        id: dialogStopAllBtn
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 98
                        Layout.alignment: Qt.AlignVCenter
                        radius: 100
                        color: dialogStopAllMouse.containsPress ? "#4D1115" : (dialogStopAllMouse.containsMouse ? "#69171C" : md.errorContainer)
                        border.color: md.error
                        border.width: 1

                        scale: dialogStopAllMouse.containsPress ? 0.94 : (dialogStopAllMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                width: 10
                                height: 10
                                radius: 2
                                color: md.errorContainerFg
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Stop All"
                                color: md.errorContainerFg
                                font.family: md.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: 12
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: dialogStopAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                spoofer.stopAllSpoofing()
                                activeGamesModal.close()
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        id: dialogDoneBtn
                        Layout.preferredHeight: 38
                        Layout.preferredWidth: 88
                        Layout.alignment: Qt.AlignVCenter
                        radius: 100
                        color: dialogDoneMouse.containsPress ? md.secondary : (dialogDoneMouse.containsMouse ? md.primary : md.primaryContainer)
                        border.color: md.primary
                        border.width: 1

                        scale: dialogDoneMouse.containsPress ? 0.94 : (dialogDoneMouse.containsMouse ? 1.03 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Done"
                            color: dialogDoneMouse.containsMouse ? md.primaryFg : md.primaryContainerFg
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: md.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: dialogDoneMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: activeGamesModal.close()
                        }
                    }
                }
            }
        }
    }
}
