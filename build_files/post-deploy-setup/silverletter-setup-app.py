#!/usr/bin/python3
"""Single-window GTK frontend for Silverletter's per-user setup."""

import os
import sys
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Vte", "3.91")
from gi.repository import Gio, GLib, Gtk, Vte


APP_ID = "io.github.networkoctopus.SilverletterSetup"
SETUP_SCRIPT = "/usr/libexec/silverletter-post-deploy-setup.sh"


class SetupWindow(Gtk.ApplicationWindow):
    def __init__(self, application: Gtk.Application, force_run: bool) -> None:
        super().__init__(application=application, title="Silverletter Setup")
        self.force_run = force_run
        self.set_default_size(780, 680)
        self.set_size_request(640, 520)
        self.set_icon_name("silverletter-setup")

        config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
        self.state_dir = config_home / "silverletter"
        self.success_file = self.state_dir / "last-run-success"
        self.skip_file = self.state_dir / "initial-setup-skipped"
        self.log_file = state_home / "silverletter/initial-setup.log"
        self.state_dir.mkdir(parents=True, exist_ok=True)

        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.set_child(self.stack)

        self._build_manage_page()
        self._build_install_page()
        self._build_remove_page()
        self._build_warning_page()
        self._build_terminal_page()
        self._build_result_page()

        self.show_page("manage" if force_run else "install")

    @staticmethod
    def heading(text: str) -> Gtk.Label:
        label = Gtk.Label()
        label.set_markup(f"<span size='x-large' weight='bold'>{GLib.markup_escape_text(text)}</span>")
        label.set_halign(Gtk.Align.START)
        label.set_wrap(True)
        return label

    @staticmethod
    def body(text: str, markup: bool = False) -> Gtk.Label:
        label = Gtk.Label()
        if markup:
            label.set_markup(text)
        else:
            label.set_text(text)
        label.set_halign(Gtk.Align.START)
        label.set_valign(Gtk.Align.START)
        label.set_xalign(0)
        label.set_wrap(True)
        return label

    @staticmethod
    def page_box() -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(28)
        box.set_margin_bottom(28)
        box.set_margin_start(32)
        box.set_margin_end(32)
        return box

    @staticmethod
    def button_row() -> Gtk.Box:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.set_halign(Gtk.Align.END)
        row.set_valign(Gtk.Align.END)
        row.set_vexpand(True)
        return row

    @staticmethod
    def button(label: str, callback, suggested: bool = False) -> Gtk.Button:
        button = Gtk.Button(label=label)
        if suggested:
            button.add_css_class("suggested-action")
        button.connect("clicked", callback)
        return button

    def add_page(self, name: str, child: Gtk.Widget) -> None:
        self.stack.add_named(child, name)

    def show_page(self, name: str) -> None:
        self.stack.set_visible_child_name(name)

    def _build_manage_page(self) -> None:
        page = self.page_box()
        page.append(self.heading("Setup"))
        page.append(self.body("Install, remove, or reset optional Silverletter components."))

        install = self.button("Install or apply components", lambda _b: self.show_page("install"), True)
        install.set_hexpand(True)
        install.set_vexpand(True)
        remove = self.button("Remove optional components", lambda _b: self.show_page("remove"))
        remove.set_hexpand(True)
        remove.set_vexpand(True)
        page.append(install)
        page.append(remove)

        row = self.button_row()
        row.append(self.button("Close", lambda _b: self.close()))
        page.append(row)
        self.add_page("manage", page)

    def _build_install_page(self) -> None:
        page = self.page_box()
        page.append(self.heading("Welcome to Silverletter"))
        page.append(self.body(
            "Choose the optional components to set up. You can install, remove, or reset them later "
            "by opening Setup from the application launcher. Default GNOME Flatpaks can be restored, "
            "and existing Flatpaks from other repositories can be replaced when Flathub provides an "
            "equivalent. They can be uninstalled in GNOME Software.\n\n"
            "<b>Setup works best when all other users are logged out, as Firefox running in another "
            "user session may prevent Firefox styling from being applied.</b>",
            markup=True,
        ))

        self.install_checks = {
            "--toshy": Gtk.CheckButton(label="Toshy keyboard remapping"),
            "--desktop-theme": Gtk.CheckButton(label="macOS-inspired desktop theme and icons"),
            "--firefox": Gtk.CheckButton(label="macOS-inspired Firefox styling"),
            "--apps": Gtk.CheckButton(label="Restore default GNOME Flatpaks"),
            "--replace-flatpaks": Gtk.CheckButton(
                label=(
                    "Replace existing Flatpaks with Flathub equivalents "
                    "(user data won't be removed)"
                )
            ),
        }
        for check in self.install_checks.values():
            check.set_active(True)
            page.append(check)

        credits = self.body(
            "Keyboard remapping is powered by <a href='https://github.com/RedBearAK/Toshy'>Toshy</a>, "
            "created by RedBearAK. The macOS-inspired themes are created by "
            "<a href='https://github.com/vinceliuice'>vinceliuice</a>.",
            markup=True,
        )
        page.append(credits)

        footer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        footer.set_halign(Gtk.Align.END)
        footer.set_valign(Gtk.Align.END)
        footer.set_vexpand(True)

        if not self.force_run:
            self.dont_open_check = Gtk.CheckButton(label="Don't open this again")
            self.dont_open_check.set_halign(Gtk.Align.END)
            self.dont_open_check.connect("toggled", self._toggle_dont_open_again)
            footer.append(self.dont_open_check)

            self.dont_open_hint = self.body(
                "<small>You can rerun Setup anytime from the GNOME Activities overview.</small>",
                markup=True,
            )
            self.dont_open_hint.set_halign(Gtk.Align.END)
            self.dont_open_hint.set_xalign(1)
            self.dont_open_hint.set_visible(False)
            footer.append(self.dont_open_hint)

        row = self.button_row()
        row.set_vexpand(False)
        if self.force_run:
            row.append(self.button("Back", lambda _b: self.show_page("manage")))
        else:
            row.append(self.button("Not now", lambda _b: self.close()))
        row.append(self.button("Install selected", lambda _b: self._prepare_install(), True))
        footer.append(row)
        page.append(footer)
        self.add_page("install", page)

    def _build_remove_page(self) -> None:
        page = self.page_box()
        page.append(self.heading("Remove optional components"))
        page.append(self.body(
            "Choose what to remove or reset. Desktop themes remain installed and can be selected "
            "again in Tweaks. GNOME Flatpak applications can be uninstalled in GNOME Software."
        ))

        self.remove_checks = {
            "--remove-toshy": Gtk.CheckButton(label="Toshy keyboard remapping"),
            "--revert-desktop-theme": Gtk.CheckButton(label="Revert macOS-inspired desktop theme and icons"),
            "--remove-firefox": Gtk.CheckButton(label="macOS-inspired Firefox styling"),
        }
        for check in self.remove_checks.values():
            page.append(check)

        row = self.button_row()
        row.append(self.button("Back", lambda _b: self.show_page("manage")))
        row.append(self.button("Remove selected", lambda _b: self._prepare_remove(), True))
        page.append(row)
        self.add_page("remove", page)

    def _build_warning_page(self) -> None:
        page = self.page_box()
        page.append(self.heading("Ready to continue"))
        self.warning_label = self.body("", markup=True)
        page.append(self.warning_label)
        row = self.button_row()
        row.append(self.button("Back", lambda _b: self.show_page(self.warning_back_page)))
        self.continue_button = self.button("Start", lambda _b: self._run_setup(), True)
        row.append(self.continue_button)
        page.append(row)
        self.add_page("warning", page)

    def _build_terminal_page(self) -> None:
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        page.set_margin_top(18)
        page.set_margin_bottom(18)
        page.set_margin_start(18)
        page.set_margin_end(18)
        page.append(self.heading("Silverletter Setup"))
        page.append(self.body("Setup output and interactive questions appear below."))

        self.terminal = Vte.Terminal()
        self.terminal.set_hexpand(True)
        self.terminal.set_vexpand(True)
        self.terminal.set_default_colors()
        self.terminal.set_scroll_on_output(True)
        self.terminal.set_scrollback_lines(5000)
        self.terminal.connect("child-exited", self._on_child_exited)
        page.append(self.terminal)
        self.add_page("terminal", page)

    def _build_result_page(self) -> None:
        page = self.page_box()
        self.result_heading = self.heading("")
        self.result_label = self.body("")
        page.append(self.result_heading)
        page.append(self.result_label)
        row = self.button_row()
        row.append(self.button("Close", lambda _b: self.close(), True))
        page.append(row)
        self.add_page("result", page)

    def _selected(self, checks: dict[str, Gtk.CheckButton]) -> list[str]:
        return [argument for argument, check in checks.items() if check.get_active()]

    def _toggle_dont_open_again(self, check: Gtk.CheckButton) -> None:
        skip = check.get_active()
        self.dont_open_hint.set_visible(skip)
        if skip:
            self.skip_file.touch()
        else:
            self.skip_file.unlink(missing_ok=True)

    def _prepare_install(self) -> None:
        arguments = self._selected(self.install_checks)
        if not arguments:
            if self.force_run:
                self.show_page("manage")
            else:
                self.close()
            return

        notes = ["The installation output will appear in this window."]
        if "--toshy" in arguments:
            notes.append(
                "<b>Important: When Toshy asks whether this machine has been updated recently, "
                "answer Yes.</b> Toshy may also ask for your sudo password and other confirmations."
            )
        if "--firefox" in arguments:
            notes.append(
                "Close Firefox before continuing. If it has never been opened, setup may open it "
                "once to initialise its profile; close it again after it loads."
            )
        if "--apps" in arguments:
            notes.append(
                "Missing default GNOME applications will be installed from Flathub."
            )
        if "--replace-flatpaks" in arguments:
            notes.append(
                "Installed system Flatpaks from other repositories will be replaced when the same "
                "application ID is available on Flathub. User data and saved permissions won't be "
                "removed."
            )
        self._prepare_run(arguments, "install", "\n\n".join(notes), "Start setup")

    def _prepare_remove(self) -> None:
        arguments = self._selected(self.remove_checks)
        if not arguments:
            self.show_page("manage")
            return

        notes = ["The removal output will appear in this window."]
        if "--remove-toshy" in arguments:
            notes.append("Toshy may ask for your sudo password and confirmation.")
        if "--remove-firefox" in arguments:
            notes.append("Close Firefox before continuing.")
        self._prepare_run(arguments, "remove", "\n\n".join(notes), "Start removal")

    def _prepare_run(self, arguments: list[str], mode: str, warning: str, button_label: str) -> None:
        self.pending_arguments = arguments
        self.pending_mode = mode
        self.warning_back_page = "install" if mode == "install" else "remove"
        self.warning_label.set_markup(warning)
        self.continue_button.set_label(button_label)
        self.show_page("warning")

    def _run_setup(self) -> None:
        try:
            self.success_file.unlink()
        except FileNotFoundError:
            pass

        self.show_page("terminal")
        self.terminal.grab_focus()
        environment = os.environ.copy()
        environment["SILVERLETTER_EMBEDDED"] = "1"
        envv = [f"{key}={value}" for key, value in environment.items()]
        argv = ["/bin/bash", SETUP_SCRIPT, *self.pending_arguments]

        try:
            self.terminal.spawn_async(
                pty_flags=Vte.PtyFlags.DEFAULT,
                working_directory=str(Path.home()),
                argv=argv,
                envv=envv,
                spawn_flags=GLib.SpawnFlags.DEFAULT,
                child_setup=None,
                timeout=-1,
                cancellable=None,
                callback=self._on_spawn_finished,
            )
        except Exception as error:
            self._show_result(False, f"The setup process could not start.\n\n{error}")

    def _on_spawn_finished(self, terminal: Vte.Terminal, pid: int, error) -> None:
        if error is not None:
            self._show_result(False, f"The setup process could not start.\n\n{error}")

    def _on_child_exited(self, _terminal: Vte.Terminal, status: int) -> None:
        succeeded = status == 0 and self.success_file.is_file()
        if succeeded:
            if self.pending_mode == "remove":
                message = "The selected optional components were removed or reset."
            else:
                message = (
                    "The selected Silverletter components are installed.\n\n"
                    "MacTahoe and WhiteSur themes are available in GNOME Tweaks under Appearance."
                )
            self._show_result(True, message)
        else:
            self._show_result(False, f"Setup could not finish.\n\nDetails: {self.log_file}")

    def _show_result(self, success: bool, message: str) -> None:
        self.result_heading.set_markup(
            "<span size='x-large' weight='bold'>"
            + ("Setup complete" if success else "Setup incomplete")
            + "</span>"
        )
        self.result_label.set_text(message)
        self.show_page("result")


class SetupApplication(Gtk.Application):
    def __init__(self, force_run: bool) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.force_run = force_run

    def do_activate(self) -> None:
        window = self.get_active_window()
        if window is None:
            window = SetupWindow(self, self.force_run)
        window.present()


def main() -> int:
    force_run = len(sys.argv) > 1 and sys.argv[1] == "--force"
    if len(sys.argv) > 1 and not force_run:
        print(f"Unknown setup option: {sys.argv[1]}", file=sys.stderr)
        return 2
    application = SetupApplication(force_run)
    return application.run([sys.argv[0]])


if __name__ == "__main__":
    raise SystemExit(main())
