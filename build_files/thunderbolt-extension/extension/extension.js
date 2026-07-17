import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const CONTROL = '/usr/libexec/silverletter-thunderbolt-control';
const STATE_FILE = '/run/silverletter/thunderbolt.state';
const ENABLED_COLOR = '#ed333b';
const ENABLING_COLOR = '#f6d32d';
const DISABLED_COLOR = '#ffffff';

const ThunderboltIndicator = GObject.registerClass({
    GTypeName: 'SilverletterThunderboltIndicator',
},
class ThunderboltIndicator extends PanelMenu.Button {
    _init(extension) {
        super._init(0.0, extension.metadata.name, false);

        this._enabled = false;
        this._busy = false;
        this._destroyed = false;
        this._refreshing = false;
        this._refreshPending = false;
        this._stateMonitor = null;

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

        this._instructionItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._instructionItem);

        this._experimentalItem = new PopupMenu.PopupMenuItem(
            'Thunderbolt support is experimental',
            {
                reactive: false,
                can_focus: false,
            }
        );
        this.menu.addMenuItem(this._experimentalItem);

        this._warningItem = new PopupMenu.PopupMenuItem(
            'Eject Thunderbolt storage before suspend',
            {
                reactive: false,
                can_focus: false,
            }
        );
        this.menu.addMenuItem(this._warningItem);

        this._actionItem = new PopupMenu.PopupMenuItem(
            'Enable Thunderbolt'
        );
        this._actionItem.connect('activate', () => this._toggleThunderbolt());
        this.menu.addMenuItem(this._actionItem);

        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._refresh();
        });

        try {
            const stateFile = Gio.File.new_for_path(STATE_FILE);
            this._stateMonitor = stateFile.monitor_file(
                Gio.FileMonitorFlags.NONE,
                null
            );
            this._stateMonitor.connect('changed', () => this._refresh());
        } catch (error) {
            console.error(`Thunderbolt state monitor failed: ${error.message}`);
        }

        this._setState('disabled');
        this._refresh();
    }

    _setState(state) {
        const enabled = state === 'armed' || state === 'active';

        this._enabled = enabled;
        this._icon.set_style(`color: ${enabled ? ENABLED_COLOR : DISABLED_COLOR};`);
        this._actionItem.label.text = enabled
            ? 'Disable Thunderbolt'
            : 'Enable Thunderbolt';
        this._warningItem.visible = enabled;

        if (state === 'active') {
            this._statusItem.label.text = 'Thunderbolt is Active';
            this._instructionItem.label.text = 'Disable before removing adapter';
            this.accessible_name = 'Thunderbolt active';
        } else if (state === 'armed') {
            this._statusItem.label.text = 'Thunderbolt is ready';
            this._instructionItem.label.text = 'Disable before removing adapter';
            this.accessible_name = 'Thunderbolt ready';
        } else {
            this._statusItem.label.text = 'Thunderbolt is powered down to save power';
            this._instructionItem.label.text = 'Enable before attaching adapter';
            this.accessible_name = 'Thunderbolt powered down';
        }
    }

    _setBusy(busy, operation = '') {
        this._busy = busy;
        this._actionItem.setSensitive(!busy);
        if (busy) {
            this._icon.set_style(`color: ${ENABLING_COLOR};`);
            this.accessible_name = operation === 'disable'
                ? 'Thunderbolt disabling'
                : 'Thunderbolt enabling';
            this._statusItem.label.text = operation === 'disable'
                ? 'Disabling Thunderbolt…'
                : 'Enabling Thunderbolt…';
        }
    }

    _setError(operation, message) {
        const disabling = operation === 'disable';

        this._enabled = disabling;
        this._icon.set_style(
            `color: ${disabling ? ENABLED_COLOR : DISABLED_COLOR};`
        );
        this._actionItem.label.text = disabling
            ? 'Disable Thunderbolt'
            : 'Enable Thunderbolt';
        this._statusItem.label.text = disabling
            ? 'Thunderbolt could not be disabled'
            : 'Thunderbolt could not be enabled';
        this._instructionItem.label.text = message;
        this.accessible_name = disabling
            ? 'Thunderbolt disablement failed'
            : 'Thunderbolt enablement failed';
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
        if (this._busy || this._destroyed)
            return;

        if (this._refreshing) {
            this._refreshPending = true;
            return;
        }

        this._refreshing = true;
        this._refreshPending = false;
        this._spawn([CONTROL, 'status'], (successful, stdout, stderr) => {
            this._refreshing = false;
            if (this._destroyed)
                return;
            if (successful) {
                const state = stdout === 'active' || stdout === 'armed'
                    ? stdout
                    : 'disabled';
                this._setState(state);
            }
            else if (stderr)
                console.error(`Thunderbolt status failed: ${stderr}`);

            if (this._refreshPending)
                this._refresh();
        });
    }

    _toggleThunderbolt() {
        if (this._busy)
            return;

        if (this._enabled)
            this._disableThunderbolt();
        else
            this._enableThunderbolt();
    }

    _enableThunderbolt() {
        this._setBusy(true, 'enable');
        this._spawn(['pkexec', CONTROL, 'enable'], (successful, stdout, stderr) => {
            if (this._destroyed)
                return;

            this._setBusy(false);
            if (successful) {
                this._setState(stdout === 'armed' ? 'armed' : 'active');
            } else {
                this._setError(
                    'enable',
                    stderr || 'The Falcon Ridge controller did not appear.'
                );
            }
        });
    }

    _disableThunderbolt() {
        this._setBusy(true, 'disable');
        this._spawn(['pkexec', CONTROL, 'disable'], (successful, _stdout, stderr) => {
            if (this._destroyed)
                return;

            this._setBusy(false);
            if (successful) {
                this._setState('disabled');
            } else {
                this._setError(
                    'disable',
                    stderr || 'The Thunderbolt controller could not be powered down.'
                );
            }
        });
    }

    destroy() {
        this._destroyed = true;
        this._stateMonitor?.cancel();
        this._stateMonitor = null;
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
