package;

import haxe.xml.Access;

using api.IdeckiaApi;
using StringTools;

typedef Props = {
	@:editable("prop_database_path")
	var database_path:String;
	@:editable("prop_database_root_folder", "")
	var database_root_folder:String;
	@:editable("prop_cache_passwords", false)
	var cache_passwords:Bool;
	@:editable("prop_group_text_size", 80)
	var group_text_size_percent:UInt;
	@:editable("prop_title_text_size", 90)
	var title_text_size_percent:UInt;
}

@:name("keepassxc")
@:description("action_description")
@:localize
class KeePassXC extends IdeckiaAction {
	var databasePassword:String = '';
	var dynamicDir:DynamicDir;

	override function init(initialState:ItemState):js.lib.Promise<ItemState> {
		assertTextSizeProps();
		if (props.cache_passwords)
			loadEntriesFromXml(initialState.textSize).then(dynDir -> dynamicDir = dynDir).catchError(e -> core.dialog.error(Loc.error_dialog_title.tr(), e));
		return super.init(initialState);
	}

	function assertTextSizeProps() {
		if (props.group_text_size_percent < 0)
			props.group_text_size_percent = 0;
		if (props.group_text_size_percent > 100)
			props.group_text_size_percent = 100;
		if (props.title_text_size_percent < 0)
			props.title_text_size_percent = 0;
		if (props.title_text_size_percent > 100)
			props.title_text_size_percent = 100;
	}

	public function execute(currentState:ItemState):js.lib.Promise<ActionOutcome> {
		return new js.lib.Promise((resolve, reject) -> {
			loadEntriesFromXml(currentState.textSize).then(dynDir -> {
				if (props.cache_passwords)
					dynamicDir = dynDir;
				resolve(new ActionOutcome({directory: dynDir}));
			}).catchError(e -> core.dialog.error(Loc.error_dialog_title.tr(), e));
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

			core.dialog.password(Loc.write_password_title.tr(), Loc.write_password_body.tr([props.database_path])).then(resp -> {
				switch resp {
					case Some(v):
						if (props.cache_passwords)
							databasePassword = v.password;
						resolve(v.password);
					case None:
						reject(Loc.no_password_provided.tr());
				}
			});
		});
	}

	function loadEntriesFromXml(textSize:UInt):js.lib.Promise<DynamicDir> {
		return new Promise<DynamicDir>((resolve, reject) -> {
			if (dynamicDir != null) {
				resolve(dynamicDir);
				return;
			}

			var args = [];

			// export
			args.push('export');
			args.push('-q');
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
						reject(Loc.error_reading_db_wrong_pass.tr([props.database_path]));
					} else {
						var items = parseXml(data, textSize);

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
						reject(Loc.error_cli_execution.tr(error));
				});

				cp.on('error', (error) -> {
					reject(Loc.error_calling_cli.tr(error));
				});
			}).catchError(error -> reject(error));
		});
	}

	function parseXml(data:String, textSize:UInt) {
		var xml = Xml.parse(data);
		var access = new Access(xml.firstElement());
		var items = [];
		parseElement(textSize, access.node.Root, '', items);
		return items;
	}

	function parseElement(textSize:UInt, access:Access, group:String, items:Array<DynamicDirItem>) {
		for (e in access.elements) {
			switch e.name {
				case 'Group':
					var groupName = e.node.Name.innerData;
					if (groupName == '' || groupName.toLowerCase().startsWith('recycle'))
						continue;
					if (props.database_root_folder != '' && !groupName.startsWith(props.database_root_folder))
						continue;

					groupName = groupName == 'Main' ? '' : groupName;
					var newGroup = group == '' ? groupName : '$group/$groupName';
					parseElement(textSize, e, newGroup, items);
				case 'Entry':
					var separatorText = 'separator:';
					var delayText = 'delay:';
					var title = '', username = '', password = '', notes;
					var ignore = false;
					var separator = '';
					var delay = 0;
					for (s in e.nodes.String) {
						var key = getInnerData(s.node.Key);
						var value = getInnerData(s.node.Value);

						if (value.startsWith('__')) {
							ignore = true;
							break;
						}
						switch key.toLowerCase() {
							case 'title':
								title = value;
							case 'username':
								username = value;
							case 'password':
								password = value;
							case 'notes':
								notes = value;
								if (notes != '') {
									for (n in notes.split(';')) {
										if (n.startsWith(separatorText))
											separator = n.replace(separatorText, '');
										if (n.startsWith(delayText))
											delay = Std.parseInt(n.replace(delayText, ''));
									}
								}
						}
					}

					if (!ignore) {
						var richGroup = new RichString('$group/ ').size(textSize * (props.group_text_size_percent / 100));
						var richTitle = new RichString(title).size(textSize * (props.title_text_size_percent / 100)).bold();
						items.push({
							text: '$richGroup$richTitle',
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
			}
		}
	}

	function getInnerData(a:Access) {
		try {
			return a.innerData;
		} catch (_) {
			return '';
		}
	}
}
