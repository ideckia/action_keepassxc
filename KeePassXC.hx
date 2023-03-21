package;

using api.IdeckiaApi;
using StringTools;

typedef Props = {
	@:editable("The path to the database")
	var database_path:String;
	@:editable("Show entries from this folder (empty shows all entries)", "")
	var database_root_folder:String;
	@:editable("Load the password at the begining and keep them in memory", false)
	var cache_passwords:Bool;
	@:editable("Name of the parent directory", {
		toDir: "_main_",
		text: "back",
		textSize: null,
		textColor: null,
		textPosition: null,
		icon: "folder",
		bgColor: "ffff0000"
	})
	var parent_dir_state:{
		toDir:String,
		text:String,
		textSize:UInt,
		textColor:String,
		textPosition:TextPosition,
		icon:String,
		bgColor:String
	};
}

@:name("keepassxc")
@:description("Load all the password saved in the keepassxc database and creates an item for each")
class KeePassXC extends IdeckiaAction {
	var databasePassword:String = '';
	var dynamicDir:DynamicDir;

	override function init(initialState:ItemState):js.lib.Promise<ItemState> {
		if (props.cache_passwords)
			loadEntriesFromCSV().then(dynDir -> dynamicDir = dynDir).catchError(e -> server.log.error(e));
		return super.init(initialState);
	}

	public function execute(currentState:ItemState):js.lib.Promise<ActionOutcome> {
		return new js.lib.Promise((resolve, reject) -> {
			loadEntriesFromCSV().then(dynDir -> {
				if (props.cache_passwords)
					dynamicDir = dynDir;
				resolve(new ActionOutcome({directory: dynDir}));
			}).catchError(e -> server.log.error(e));
		});
	}

	override public function onLongPress(currentState:ItemState):js.lib.Promise<ActionOutcome> {
		databasePassword = '';
		dynamicDir = null;
		return execute(currentState);
	}

	function getKeePassXCPassword() {
		return new js.lib.Promise((resolve, reject) -> {
			if (databasePassword != '') {
				resolve(databasePassword);
				return;
			}

			server.dialog.password('KeePassXC [${haxe.io.Path.withoutDirectory(props.database_path)}] file password',
				'Write the KeePassXC [${props.database_path}] file password, please')
				.then(resp -> {
					switch resp {
						case Some(v):
							if (props.cache_passwords)
								databasePassword = v.password;
							resolve(v.password);
						case None:
							reject('No password provided');
					}
				});
		});
	}

	function loadEntriesFromCSV():js.lib.Promise<DynamicDir> {
		return new Promise<DynamicDir>((resolve, reject) -> {
			if (dynamicDir != null) {
				resolve(dynamicDir);
				return;
			}

			var args = [];

			// export
			args.push('export');
			args.push('-q');
			args.push('-f');
			args.push('csv');
			args.push(props.database_path);
			var cp = js.node.ChildProcess.spawn('keepassxc-cli', args, {shell: true});

			var data = '';
			var error = '';

			getKeePassXCPassword().then(password -> {
				cp.stdin.write(password + '\n');

				cp.stdout.on('data', d -> data += d);
				cp.stdout.on('end', d -> {
					var lineBreakEreg = ~/\r?\n/g;
					var cleanData = lineBreakEreg.replace(data, '');
					if (cleanData.length == 0) {
						reject(error);
					} else {
						var lines = lineBreakEreg.split(data);

						lines.shift();
						var groupIndex = 0;
						var titleIndex = 1;
						var usernameIndex = 2;
						var passwordIndex = 3;
						var notesIndex = 5;

						var items:Array<DynamicDirItem> = [];

						inline function removeQuotes(s:String) {
							if (s == null || s.length == 0)
								return '';
							return s.substring(1, s.length - 1);
						}

						var separatorText = 'separator:';
						var delayText = 'delay:';
						var tokens, group, title, username, password, notes, entryName;
						var separator = '';
						var delay = 0;
						for (l in lines) {
							separator = 'tab';
							delay = 0;
							tokens = l.split(',');

							group = removeQuotes(tokens[groupIndex]);
							if (group == '' || group.toLowerCase().startsWith('recycle'))
								continue;
							group = group.substring(group.indexOf('/') + 1, group.length);

							if (props.database_root_folder != '' && !group.startsWith(props.database_root_folder))
								continue;

							title = removeQuotes(tokens[titleIndex]);
							username = removeQuotes(tokens[usernameIndex]);
							password = removeQuotes(tokens[passwordIndex]);
							notes = removeQuotes(tokens[notesIndex]);
							if (notes != '') {
								for (n in notes.split(';')) {
									if (n.startsWith(separatorText))
										separator = n.replace(separatorText, '');
									if (n.startsWith(delayText))
										delay = Std.parseInt(n.replace(delayText, ''));
								}
							}

							entryName = '$group/$title';
							items.push({
								text: entryName,
								actions: [
									{
										name: 'log-in',
										props: {
											username: username,
											password: password,
											key_after_user: separator,
											user_pass_delay: delay
										}
									}
								]
							});
						}

						if (props.parent_dir_state != null)
							items.unshift(cast props.parent_dir_state);

						var rows = 2;
						var columns = 2;
						while (rows * columns < items.length) {
							rows++;
							if (rows * columns >= items.length)
								break;
							columns++;
						}
						resolve({
							rows: rows,
							columns: columns,
							items: items
						});
					}
				});
				cp.stderr.on('data', e -> error += e);
				cp.stderr.on('end', e -> {
					if (error != '')
						reject('Error in keepassxc-cli execution: $error');
				});

				cp.on('error', (error) -> {
					reject('Error calling keepassxc-cli: $error');
				});
			}).catchError(error -> reject('Error getting keepassxc password: $error'));
		});
	}
}
