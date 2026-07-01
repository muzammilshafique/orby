import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Orby 1.0

Window {
    id: window
    width: 600
    height: 700
    visible: true
    title: "Orby - Discord Game Spoofer"
    color: "#0a0a0c" // Very dark gray, almost black
    
    // Smooth window rendering
    // Native window styling is used so no frameless flags are needed

    DiscordApi {
        id: discordApi
        Component.onCompleted: fetchGames()
        onErrorOccurred: (msg) => console.log("Discord API Error:", msg)
    }

    ProcessSpoofer {
        id: spoofer
        onErrorOccurred: (msg) => console.log("Spoofer Error:", msg)
    }

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
        function onGamesChanged() {
            updateFilter()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 20

        // Header
        ColumnLayout {
            spacing: 8
            Text {
                text: "Discord Presence"
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 28
                font.weight: Font.Bold
                font.letterSpacing: -0.5
            }
            Text {
                text: "Spoof your activity status natively on Linux."
                color: "#8e8e93"
                font.family: "Inter"
                font.pixelSize: 14
            }
        }

        // Active Spoofer Banner
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            radius: 12
            color: spoofer.isSpoofing ? "#1a2a1a" : "#1a1a1e"
            border.color: spoofer.isSpoofing ? "#336633" : "#2a2a2e"
            border.width: 1
            visible: true
            
            Behavior on color { ColorAnimation { duration: 300; easing.type: Easing.OutQuint } }
            Behavior on border.color { ColorAnimation { duration: 300; easing.type: Easing.OutQuint } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                
                ColumnLayout {
                    spacing: 4
                    Text {
                        text: spoofer.isSpoofing ? "Currently Spoofing" : "Not Spoofing"
                        color: spoofer.isSpoofing ? "#4ade80" : "#888888"
                        font.family: "Inter"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        font.capitalization: Font.AllUppercase
                    }
                    Text {
                        text: spoofer.isSpoofing ? spoofer.currentProcessName : "Select a game below"
                        color: "#ffffff"
                        font.family: "Inter"
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                
                Item { Layout.fillWidth: true }
                
                Button {
                    visible: spoofer.isSpoofing
                    text: "Stop"
                    font.family: "Inter"
                    font.weight: Font.DemiBold
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    
                    background: Rectangle {
                        color: parent.hovered ? "#ff4444" : "#cc3333"
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font: parent.font
                    }
                    onClicked: spoofer.stopSpoofing()
                }
            }
        }

        // Search Input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            color: "#16161a"
            border.color: searchInput.activeFocus ? "#5865F2" : "#2a2a2e"
            border.width: 1
            radius: 8
            
            Behavior on border.color { ColorAnimation { duration: 200 } }

            TextInput {
                id: searchInput
                anchors.fill: parent
                anchors.margins: 12
                verticalAlignment: TextInput.AlignVCenter
                color: "#ffffff"
                font.family: "Inter"
                font.pixelSize: 15
                selectionColor: "#5865F2"
                selectByMouse: true
                
                Text {
                    anchors.fill: parent
                    text: "Search games..."
                    color: "#555555"
                    font: parent.font
                    verticalAlignment: TextInput.AlignVCenter
                    visible: !parent.text && !parent.activeFocus
                }
                
                onTextChanged: updateFilter()
            }
        }

        // List
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
                
                delegate: Rectangle {
                    width: ListView.view.width
                    height: 60
                    radius: 8
                    color: delegateMouseArea.containsMouse ? "#1c1c20" : "transparent"
                    border.color: delegateMouseArea.containsMouse ? "#3a3a40" : "transparent"
                    border.width: 1
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: modelData.name
                                color: "#ffffff"
                                font.family: "Inter"
                                font.pixelSize: 15
                                font.weight: Font.Medium
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.primaryExecutable
                                color: "#666666"
                                font.family: "Inter"
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        Button {
                            text: spoofer.currentProcessName === modelData.primaryExecutable && spoofer.isSpoofing ? "Active" : "Spoof"
                            enabled: !(spoofer.currentProcessName === modelData.primaryExecutable && spoofer.isSpoofing)
                            font.family: "Inter"
                            font.weight: Font.DemiBold
                            font.pixelSize: 13
                            Layout.preferredWidth: 70
                            Layout.preferredHeight: 32
                            
                            background: Rectangle {
                                color: !parent.enabled ? "#2a2a2e" : (parent.hovered ? "#4752C4" : "#5865F2")
                                radius: 6
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Text {
                                text: parent.text
                                color: !parent.enabled ? "#666666" : "#ffffff"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }
                            
                            onClicked: {
                                spoofer.startSpoofing(modelData.primaryExecutable)
                            }
                        }
                    }
                    
                    MouseArea {
                        id: delegateMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
            
            // Loading indicator
            Text {
                anchors.centerIn: parent
                text: "Loading verifiable games..."
                color: "#888888"
                font.family: "Inter"
                font.pixelSize: 14
                visible: discordApi.isLoading
            }
            
            // No results
            Text {
                anchors.centerIn: parent
                text: "No games found."
                color: "#888888"
                font.family: "Inter"
                font.pixelSize: 14
                visible: !discordApi.isLoading && gameListView.count === 0
            }
        }
    }
}
