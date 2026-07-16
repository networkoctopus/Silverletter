import Gio from 'gi://Gio';
import GObject from 'gi://GObject';
import St from 'gi://St';

import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

const CONTROL = '/usr/libexec/silverletter-thunderbolt-control';
const ENABLED_COLOR = '#ed333b';
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

        this._actionItem = new PopupMenu.PopupMenuItem('Enable Thunderbolt until next reboot');
        this._actionItem.connect('activate', () => this._enableThunderbolt());
        this.menu.addMenuItem(this._actionItem);

        this._instructionItem = new PopupMenu.PopupMenuItem('', {
            reactive: false,
            can_focus: false,
        });
        this.menu.addMenuItem(this._instructionItem);

        this._warningItem = new PopupMenu.PopupMenuItem(
            'Experimental: attached devices may cause system instability',
            {
                reactive: false,
                can_focus: false,
            }
        );
        this.menu.addMenuItem(this._warningItem);

        this.menu.connect('open-state-changed', (_menu, open) => {
            if (open)
                this._refresh();
        });

        this._setState(false);
        this._refresh();
    }

    _setState(enabled) {
        this._enabled = enabled;
        this._icon.set_style(`color: ${enabled ? ENABLED_COLOR : DISABLED_COLOR};`);
        this._statusItem.label.text = enabled
            ? 'Thunderbolt is enabled until the next reboot'
            : 'Thunderbolt is powered down to save power';
        this._actionItem.visible = !enabled;
        this._instructionItem.label.text = enabled
            ? 'Connect your Thunderbolt adapter now'
            : 'Enable only when you need the port';
        this.accessible_name = enabled
            ? 'Thunderbolt enabled'
            : 'Thunderbolt powered down';
    }

    _setBusy(busy) {
        this._busy = busy;
        this._actionItem.setSensitive(!busy);
        if (busy)
            this._statusItem.label.text = 'Enabling Thunderbolt…';
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

        this._spawn([CONTROL, 'status'], (successful, stdout, stderr) => {
            if (this._destroyed)
                return;
            if (successful)
                this._setState(stdout === 'enabled');
            else if (stderr)
                console.error(`Thunderbolt status failed: ${stderr}`);
        });
    }

    _enableThunderbolt() {
        if (this._busy || this._enabled)
            return;

        Main.notify(
            'Experimental Thunderbolt support',
            'Connected devices may cause system instability. Reboot to restore the default powered-down state.'
        );
        this._setBusy(true);
        this._spawn(['pkexec', CONTROL, 'enable'], (successful, _stdout, stderr) => {
            if (this._destroyed)
                return;

            this._setBusy(false);
            if (successful) {
                Main.notify(
                    'Thunderbolt enabled until next reboot',
                    'Connect your Thunderbolt adapter now.'
                );
            } else {
                Main.notifyError(
                    'Thunderbolt could not be enabled',
                    stderr || 'The Falcon Ridge controller did not appear.'
                );
            }
            this._refresh();
        });
    }

    destroy() {
        this._destroyed = true;
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
