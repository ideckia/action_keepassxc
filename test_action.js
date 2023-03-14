const { IdeckiaAction } = require('.');

// put here the properties you want to test
const props = {};

const server = {
    log: {
        error: text => console.error(text),
        debug: text => console.debug(text),
        info: text => console.info(text)
    },
    dialog: {
        setDefaultOptions: (options) => console.log(options),
        notify: (title, _text) => console.log(title),
        info: (title, _text) => console.log(title),
        warning: (title, _text) => console.log(title),
        error: (title, _text) => console.log(title),
        question: (title, _text) => {
            console.log(title);
            return Promise.resolve(true);
        },
        selectFile: (title, _isDirectory = false, _multiple = false, _fileFilter = null) => {
            console.log(title);
            return Promise.resolve(['file0path', 'file1path']);
        },
        saveFile: (title, _saveName = null, _fileFilter = null) => {
            console.log(title);
            return Promise.resolve('filepath');
        },
        entry: (title, _text, _placeholder = null) => {
            console.log(title);
            return Promise.resolve('');
        },
        password: (title, _text, _username = false) => {
            console.log(title);
            return Promise.resolve(['username', 'password']);
        },
        progress: (title, _text, _pulsate = false, _autoClose = true) => {
            console.log(title);
            return {
                progress: (percentage) => console.log(`progress: ${percentage}`)
            };
        },
        color: (title, _initialColor = "#FFFFFF", _palette = false) => {
            console.log(title);
            return Promise.resolve({ red: 192, green: 192, blue: 192 });
        },
        calendar: (title, _text, _year = null, _month = null, _day = null, _dateFormat = null) => {
            console.log(title);
            return Promise.resolve(new Date().toString());
        },
        list: (title, _text, _columnHeader, _values, _multiple = false) => {
            console.log(title);
            return Promise.resolve(['item0', 'item1']);
        },
    },
    mediaPlayer: {
        play: (path) => {
            console.log(`Playing ${path} file.`);
            return 0;
        },
        pause: (id) => {
            console.log(`Pause ${id} media.`);
        },
        stop: (id) => {
            console.log(`Stop ${id} media.`);
        },
    },
    updateClientState: state => console.log('New state sent to the client: ' + state)
};

const action = new IdeckiaAction();
action.setup(props, server);

const itemState = {
    text: 'State text',
    textSize: 15,
    textColor: '0x333333',
    icon: '',
    bgColor: '0x999999',
}
action.init(itemState);
action.execute(itemState)
    .then(responseState => console.log(responseState))
    .catch(error => console.error('Rejected: ' + error));