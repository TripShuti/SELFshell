// ============================================================
// quickshell/popups/SettingsPopup.qml — налаштування: Bar (з Layout всередині), Popups, Hyprland, Appearance, Wallpaper, Behavior, Binds, About.
// ============================================================
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"

AnimatedPopup {
  id: root

  required property QtObject window
  palette: window.palette
  appConfig: window.appConfig

  // Фіксований розмір вікна: якщо контенту сторінки забагато,
  // він скролиться всередині (pageFlick) замість розтягування вікна
  implicitWidth: 760
  implicitHeight: 560
  enterScale: 0.75
  slideDistance: 6
  transformOrigin: Item.Center

  readonly property int screenW: window ? window.screen.width : 1920
  readonly property int screenH: window ? window.screen.height : 1080

  // Адаптер config.json (дані) і обгортка (хелпери isSep/addSep/...)
  readonly property var cfg: window.appConfig.cfg
  readonly property var ac: window.appConfig

  // Розділи: Bar (з Layout всередині), Popups, Hyprland, Appearance (Scale/Animations), решта — без змін
  readonly property var sections: [
    { title: "Bar", page: "settings/BarSection.qml" },
    { title: "Popups", page: "settings/PopupsSection.qml" },
    { title: "Hyprland", page: "settings/HyprlandSection.qml" },
    { title: "Appearance", page: "settings/AppearanceSection.qml" },
    { title: "Wallpaper", page: "settings/WallpaperSection.qml" },
    { title: "Behavior", page: "settings/BehaviorSection.qml" },
    { title: "Binds", page: "settings/BindsSection.qml" },
    { title: "About", page: "settings/AboutSection.qml" }
  ]
  property int section: 0

  Component.onCompleted: { anchor.window = window }

  // Вікно фіксоване — центруємо один раз при показі
  function recenter() {
    anchor.rect = Qt.rect(
      (screenW - root.implicitWidth) / 2,
      (screenH - root.implicitHeight) / 2,
      root.implicitWidth,
      root.implicitHeight
    )
  }

  onVisibleChanged: {
    if (visible) {
      anchor.edges = PopupAnchor.None
      anchor.gravity = PopupAnchor.None
      root.recenter()
      // На кожному моніторі свій інстанс попапа зі своїм станом секцій —
      // без resync редагування на одному моніторі губилося б при відкритті
      // на іншому (стан секцій застарів)
      sectionLoader.item?.resync?.()
    } else if (sectionLoader.item?.cancelDrag) {
      // Перетягування скасовується без коміту (раніше onVisibleChanged
      // викликав commitDrag, і "закривши" драг все одно переносив/вимикав віджет)
      sectionLoader.item.cancelDrag()
    }
  }

  RowLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    // --- Бічна панель розділів: ширина під текст (плюс паддинги) ---
    Rectangle {
      Layout.preferredWidth: tabsCol.implicitWidth + 16
      Layout.fillHeight: true
      radius: 8
      color: window.palette.bg1
      border.width: 1
      border.color: window.palette.bg2

      ColumnLayout {
        id: tabsCol
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        Repeater {
          model: root.sections
          delegate: Rectangle {
            id: tabBtn
            required property var modelData
            required property int index
            readonly property bool active: root.section === tabBtn.index

            // fillWidth розтягує кнопку на всю панель, preferredWidth
            // задає панелі ширину по тексту (tabsCol.implicitWidth)
            Layout.fillWidth: true
            Layout.preferredWidth: tabText.implicitWidth + 32
            Layout.preferredHeight: 36
            radius: 5
            color: tabBtn.active
                   ? window.palette.accent
                   : (tabMa.containsMouse ? window.palette.bg2 : "transparent")
            Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }

            Text {
              id: tabText
              anchors.centerIn: parent
              width: parent.width - 16
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              text: tabBtn.modelData.title
              color: tabBtn.active ? window.palette.bg0H : window.palette.fg
              font.family: window.palette.font
              font.pixelSize: appConfig.scaled(11)
              font.bold: true
              Behavior on color { ColorAnimation { duration: appConfig.anim(120) } }
            }

            MouseArea {
              id: tabMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.section = tabBtn.index
            }
          }
        }

        Item { Layout.fillHeight: true }
      }
    }

    // --- Контент: заголовок + скролована сторінка розділу ---
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 10

      Text {
        text: "\u2699 Settings"
        color: window.palette.fg
        font.family: window.palette.font
        font.pixelSize: appConfig.scaled(16)
        font.bold: true
      }

      // Скрол сторінки: контент заввишки як сама сторінка, в'юпорт —
      // висота вікна; коли сторінка вища за в'юпорт, з'являється
      // прокрутка. Патерн той самий, що в ControlPopup (notifFlick).
      Flickable {
        id: pageFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: pageFlick.width
        contentHeight: sectionLoader.item?.implicitHeight ?? 0
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > pageFlick.height

        // Вміст поточного розділу: setSource з готовим sys, щоб сторінка
        // не будувалась із порожньою прив'язкою до палітри
        Loader {
          id: sectionLoader
          width: pageFlick.width
          asynchronous: true

          function reload() {
            setSource(root.sections[root.section].page, { sys: root })
          }
          Component.onCompleted: reload()

          Connections {
            target: root
            function onSectionChanged() { sectionLoader.reload() }
          }
        }
      }
    }
  }
}