import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:bullet_train/bullet_train.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

final GetIt getIt = GetIt.instance;
const String testFeature = 'show_title_logo';

/// Prepare DI for [BulletTrainSampleApp]

void setupPrefs() {
  getIt.registerSingleton<BulletTrainClient>(BulletTrainClient(
      apiKey: 'EBnVjhp7xvkT5oTLq4q7Ny',
      config:
          BulletTrainConfig(storeType: StoreType.persistant, isDebug: true)));

  getIt.registerFactory(() => FlagBloc(bt: getIt<BulletTrainClient>()));
  return null;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupPrefs();
  runApp(BulletTrainSampleApp());
}

/// Simple [BulletTrainSampleApp]
class BulletTrainSampleApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bullet Train Example',
      theme: ThemeData(
        textTheme: GoogleFonts.varelaRoundTextTheme(
          Theme.of(context).textTheme,
        ),
        primaryColor: Color.fromARGB(255, 35, 61, 83),
        accentColor: Color(0xff1c9997),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: BlocProvider(
        create: (context) => getIt<FlagBloc>()
          ..add(FlagEvent.personalize)
          ..add(FlagEvent.initial),
        child: BulletTrainSampleScreen(title: 'Bullet Train Example'),
      ),
    );
  }
}

/// Sample screen
class BulletTrainSampleScreen extends StatelessWidget {
  // Screen title
  final String title;
  BulletTrainSampleScreen({Key key, this.title}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FlagBloc, FlagState>(
        listener: (context, state) {},
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: state.isEnabled(testFeature)
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://docs.bullet-train.io/images/logo.png',
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(
                          width: 8,
                        ),
                        Text(title + '/${state.isEnabled(testFeature)}'),
                      ],
                    )
                  : Text(title + '/${state.isEnabled(testFeature)}'),
              centerTitle: Platform.isIOS,
            ),
            body: SafeArea(
              child: state.loading == LoadingState.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        context.bloc<FlagBloc>().add(FlagEvent.fetch);
                        return null;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8.0),
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          indent: 16,
                        ),
                        itemCount: state.flags.length,
                        itemBuilder: (context, index) {
                          var item = state.flags[index];
                          return SwitchListTile.adaptive(
                              title: Text(item.feature.description ??
                                  item.feature.name ??
                                  'no description'),
                              subtitle: item.feature.description != null
                                  ? Text(
                                      'feature: ${item.feature.name}\ntype: ${describeEnum(item.feature.type)}')
                                  : Text(
                                      'type: ${describeEnum(item.feature.type)}'),
                              value: item.enabled,
                              onChanged: (bool value) {});
                        },
                      ),
                    ),
            ),

            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: () =>
                      context.bloc<FlagBloc>().add(FlagEvent.toggle),
                  child: Icon(Icons.account_circle),
                ),
                FloatingActionButton.extended(
                  onPressed: () =>
                      context.bloc<FlagBloc>().add(FlagEvent.fetch),
                  tooltip: 'Fetch',
                  icon: Icon(Icons.add),
                  label: Text('Fetch'),
                ),
              ],
            ), // This trailing comma makes auto-formatting nicer for build methods.
          );
        });
  }
}

extension BuildContextX on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;
}

class CardTileWidget extends StatelessWidget {
  final Flag item;
  const CardTileWidget({Key key, @required this.item})
      : assert(item != null, 'missing data'),
        super(key: key);
  @override
  Widget build(BuildContext context) {
    var color =
        item.feature.name == 'color' ? Hexcolor(item.stateValue) : Colors.black;
    return Card(
      elevation: 1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.feature?.name,
            style: context.textTheme.headline5.copyWith(color: color),
          )
        ],
      ),
    );
  }
}

/// State of network call for UI
enum LoadingState { isInitial, isLoading, isComplete }

/// Simple [FlagEvent] enum for [FlagBloc]
enum FlagEvent {
  /// Notifies bloc to fetch flags from API
  initial,

  /// set stream listeners after fetch data
  register,

  /// Notifies bloc to fetch flags from API
  fetch,
  // Notifies bloc to update user traits
  personalize,

  // reload from storage
  reload,
  // toggle feature
  toggle
}

/// Simple [FlagState] for [FlagBloc]
class FlagState extends Equatable {
  // Loading state of bloc
  final LoadingState loading;
  // Loaded flag list
  final List<Flag> flags;

  @override
  List<Object> get props => [loading, flags];

  const FlagState({@required this.loading, this.flags})
      : assert(loading != null);

  FlagState copyWith({LoadingState loading, List<Flag> flags}) {
    return FlagState(
        loading: loading ?? this.loading, flags: flags ?? this.flags);
  }

  /// Initial state
  factory FlagState.initial() =>
      FlagState(loading: LoadingState.isInitial, flags: []);

  bool isEnabled(String flag) =>
      flags.firstWhere(
        (element) => element.feature.name == flag && element.enabled == true,
        orElse: () => null,
      ) !=
      null;
}

/// A simple [Bloc] which manages an `FlagState` as its state.
class FlagBloc extends Bloc<FlagEvent, FlagState> {
  final BulletTrainClient bt;

  StreamSubscription<Flag> _behaviorSubject;
  FlagBloc({@required this.bt})
      : assert(bt != null),
        super(FlagState.initial());

  @override
  Stream<FlagState> mapEventToState(FlagEvent event) async* {
    switch (event) {
      case FlagEvent.initial:
        yield state.copyWith(loading: LoadingState.isInitial);
        add(FlagEvent.register);
        add(FlagEvent.fetch);

        break;
      case FlagEvent.fetch:
        yield state.copyWith(loading: LoadingState.isLoading);
        var result = await bt.getFeatureFlags();
        yield state.copyWith(loading: LoadingState.isComplete, flags: result);
        add(FlagEvent.register);
        break;
      case FlagEvent.reload:
        yield state.copyWith(loading: LoadingState.isLoading);
        var result = await bt.getFeatureFlags(reload: false);
        yield state.copyWith(loading: LoadingState.isComplete, flags: result);
        break;
      case FlagEvent.personalize:
        yield state.copyWith(loading: LoadingState.isLoading);
        await bt.updateTrait(FeatureUser(identifier: 'testUser'),
            Trait(key: 'age', value: '21'));
        break;
      case FlagEvent.register:
        _behaviorSubject ??= bt.stream(testFeature)?.listen((event) {
          log('LISTEN: ${event.feature.name} => ${event.enabled}');
          add(FlagEvent.reload);
        });
        break;
      case FlagEvent.toggle:
        await bt.testToggle(testFeature);
        break;
      default:
        addError(Exception('unsupported event'));
    }
  }

  Future<bool> isEnabled(String featureName, {FeatureUser user}) =>
      bt.hasFeatureFlag(featureName, user: user);

  @override
  Future<void> close() {
    _behaviorSubject?.cancel();
    return super.close();
  }
}
