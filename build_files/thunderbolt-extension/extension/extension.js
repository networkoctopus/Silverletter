import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const CONTROL = '/usr/libexec/silverletter-thunderbolt-control';
const STATE_DIR = '/run/silverletter';
const ENABLED_COLOR = '#ed333b';
const DISABLED_COLOR = '#ffffff';

const ThunderboltIndicator = GObject.registerClass({
    GTypeName: 'SilverletterThunderboltIndicator',
},
class ThunderboltIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.0, extension.metadata.name, false);

        this._state = 'disabled';
        this._destroyed = false;
        this._refreshing = false;
        this._refreshPending = false;

        const iconPath = extension.dir.get_child('icons').get_child('thunderbolt-symbolic.svg').get_path();
        this._icon = new St.Icon({
            gicon: Gio.icon_new_for_string(iconPath),
            style_class: 'system-status-icon',
        });
        this.add_child(this._icon);

        this._statusItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._statusItem);

        this._powerItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._powerItem);

        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._refresh();
        });

        // The backend touches a state-change file after every transition. A
        // directory monitor updates the icon without periodic polling or its
        // associated process and wake-up overhead.
        try {
            this._stateMonitor = Gio.File.new_for_path(STATE_DIR).monitor_directory(
                Gio.FileMonitorFlags.NONE,
                null
            );
            this._stateMonitorId = this._stateMonitor.connect('changed', () => this._refresh());
        } catch (error) {
            console.error(`Thunderbolt state monitor failed: ${error.message}`);
            this._stateMonitor = null;
            this._stateMonitorId = 0;
        }

        // The pre-sleep service always powers the hierarchy down. Refresh on
        // resume as a fallback even if no filesystem event reaches the shell.
        this._sleepSignalId = Gio.DBus.system.signal_subscribe(
            'org.freedesktop.login1',
            'org.freedesktop.login1.Manager',
            'PrepareForSleep',
            '/org/freedesktop/login1',
            null,
            Gio.DBusSignalFlags.NONE,
            (_connection, _sender, _path, _interface, _signal, parameters) => {
                const [preparingForSleep] = parameters.deepUnpack();
                if (!preparingForSleep)
                    this._refresh();
            }
        );

        this._setState('disabled');
        this._refresh();
    }

    _setState(state) {
        const adapterPresent = state === 'enabled' || state === 'ready';
        const warning = state === 'powerdown-incomplete';

        this._state = state;
        this._icon.set_style(`color: ${adapterPresent || warning ? ENABLED_COLOR : DISABLED_COLOR};`);
        this._powerItem.visible = state !== 'enabled';

        if (state === 'enabled') {
            this._statusItem.label.text = 'Thunderbolt is in use';
            this.accessible_name = 'Thunderbolt in use';
        } else if (state === 'ready') {
            this._statusItem.label.text = 'Thunderbolt connection is pending';
            this._powerItem.label.text = 'Waiting for the adapter to finish connecting';
            this.accessible_name = 'Thunderbolt connection pending';
        } else if (state === 'powering-down') {
            this._statusItem.label.text = 'Thunderbolt is powering down';
            this._powerItem.label.text = 'Maximum power saving is being restored';
            this.accessible_name = 'Thunderbolt powering down';
        } else if (state === 'powerdown-incomplete') {
            this._statusItem.label.text = 'Thunderbolt power-down is incomplete';
            this._powerItem.label.text = 'Maximum power saving is not active';
            this.accessible_name = 'Thunderbolt power-down incomplete';
        } else {
            this._statusItem.label.text = 'Thunderbolt is powered down';
            this._powerItem.label.text = 'Connect an adapter to enable it';
            this.accessible_name = 'Thunderbolt powered down';
        }
    }

    _spawn(argv, callback) {
        let process;
        try {
            process = Gio.Subprocess.new(
                argv,
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_PIPE
            );
        } catch (error) {
            callback(false, '', error.message);
            return;
        }

        process.communicate_utf8_async(null, null, (source, result) => {
            try {
                const [, stdout, stderr] = source.communicate_utf8_finish(result);
                callback(source.get_successful(), stdout.trim(), stderr.trim());
            } catch (error) {
                callback(false, '', error.message);
            }
        });
    }

    _refresh() {
        if (this._destroyed)
            return;
        if (this._refreshing) {
            this._refreshPending = true;
            return;
        }

        this._refreshing = true;
        this._spawn([CONTROL, 'status'], (successful, stdout, stderr) => {
            this._refreshing = false;
            if (this._destroyed)
                return;

            if (successful && ['enabled', 'disabled', 'ready', 'powering-down', 'powerdown-incomplete'].includes(stdout))
                this._setState(stdout);
            else if (!successful && stderr)
                console.error(`Thunderbolt status failed: ${stderr}`);

            if (this._refreshPending) {
                this._refreshPending = false;
                this._refresh();
            }
        });
    }

    destroy() {
        this._destroyed = true;
        if (this._stateMonitor) {
            if (this._stateMonitorId)
                this._stateMonitor.disconnect(this._stateMonitorId);
            this._stateMonitor.cancel();
            this._stateMonitor = null;
            this._stateMonitorId = 0;
        }
        if (this._sleepSignalId) {
            Gio.DBus.system.signal_unsubscribe(this._sleepSignalId);
            this._sleepSignalId = 0;
        }
        super.destroy();
    }
});

export default class ThunderboltExtension extends Extension {
    enable() {
        this._indicator = new ThunderboltIndicator(this);
        Main.panel.addToStatusArea(this.uuid, this._indicator);
    }

    disable() {
        this._indicator?.destroy();
        this._indicator = null;
    }
}
