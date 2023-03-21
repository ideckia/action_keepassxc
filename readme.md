# Action for [ideckia](https://ideckia.github.io/): keepassxc

## Description

Load all the password saved in the keepassxc database and creates an item for each

## Properties

| Name | Type | Description | Shared | Default | Possible values |
| ----- |----- | ----- | ----- | ----- | ----- |
| database_path | String | The path to the database | false | null | null |
| database_root_folder | String | Show entries from this folder (empty shows all entries) | false | "" | null |
| cache_passwords | Bool | Load the password at the begining and keep them in memory | false | false | null |
| parent_dir_state | { toDir : String, textSize : UInt, textPosition : api.TextPosition, textColor : String, text : String, icon : String, bgColor : String } | Name of the parent directory | false | { toDir : "_main_", text : "back", textSize : null, textColor : null, textPosition : null, icon : "folder", bgColor : "ffff0000" } | null |

## On single click

Get entries from [KeePassXC](https://keepassxc.org/) application and creates a directory with an item for each entry.

Action ['action_log-in'](http://github.com/ideckia/action_log-in) is required.

When the action is initialized, it will get the entry content and will keep it in memory. If you want to reload the entry (if you have updated it), do it with a long press.

## On long press

Reloads the items from the database (asks for the password on every long press)

## Test the action

There is a script called `test_action.js` to test the new action. Set the `props` variable in the script with the properties you want and run this command:

```
node test_action.js
```

## Example in layout file

```json
{
    "text": "KeePassXC example",
    "bgColor": "00ff00",
    "actions": [
        {
            "name": "keepassxc",
            "props": {
                "database_path": "/home/ideckia/passwords.kdbx",
                "database_root_folder": "",
                "cache_passwords": true,
                "parent_dir_state": {
                    "toDir" : "_main_",
                    "text" : "back",
                    "textSize" : null,
                    "textColor" : null,
                    "textPosition" : null,
                    "icon" : "folder",
                    "bgColor" : "ffff0000"
                }
            }
        }
    ]
}
```