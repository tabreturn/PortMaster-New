import { program, Option } from 'commander';

export default function getOptions() {
  let rom = null;
  program
    .allowUnknownOption()
    .name('js game launcher')
    .description('js game launcher')
    .version('1.0')
    .argument('[romfile]', 'rom file (directory of javascript game / rom file)')
    .action((romfile) => {
      rom = romfile;
    })
    .addOption(new Option('-rom <string>', 'rom file (directory of javascript game / rom file)'))
    .addOption(new Option('-fs, -fullscreen', 'fullscreen mode'))
    .addOption(new Option('-fps, -showfps', 'show fps'))
    .addOption(new Option('-aa, -antialiasing, -antialias', 'antialias mode'))
    .addOption(new Option('-s, -stretch', 'ignore aspect ratio, stretch to fit window'))
    .addOption(new Option('-is, -integerscaling', 'only scale by integer values (possible black bars top and bottom)'))
    .addOption(new Option('-p1index <string>', 'player 1 controller index'))
    .addOption(new Option('-p2index <string>', 'player 2 controller index'))
    .addOption(new Option('-p3index <string>', 'player 3 controller index'))
    .addOption(new Option('-p4index <string>', 'player 4 controller index'))
    .addOption(new Option('-p1name <string>', 'player 1 controller name'))
    .addOption(new Option('-p2name <string>', 'player 2 controller name'))
    .addOption(new Option('-p3name <string>', 'player 3 controller name'))
    .addOption(new Option('-p4name <string>', 'player 4 controller name'))
    .addOption(new Option('-p1guid <string>', 'player 1 controller guid'))
    .addOption(new Option('-p2guid <string>', 'player 2 controller guid'))
    .addOption(new Option('-p3guid <string>', 'player 3 controller guid'))
    .addOption(new Option('-p4guid <string>', 'player 4 controller guid'))
    .addOption(new Option('-addconcfg <string>', 'additional controller config (emulationstation es_input.cfg format)'))
    .addOption(new Option('-gameinfoxml <string>', 'game info xml (emulationstation format)'))
    .parse(process.argv);

  const options = program.opts();
  options.Rom = options.Rom || rom;
  return options;
};
