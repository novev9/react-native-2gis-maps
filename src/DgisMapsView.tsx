import type { ColorValue, ViewProps } from 'react-native';

type Props = ViewProps & {
  color?: ColorValue;
};

export function DgisMapsView(_props: Props): never {
  throw new Error(
    "'react-native-dgis-maps' is only supported on native platforms."
  );
}
