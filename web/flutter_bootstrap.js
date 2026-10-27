{{flutter_js}}
{{flutter_build_config}}
_flutter.loader.load({config:{canvasKitBaseUrl:'canvaskit/'},onEntrypointLoaded:async function(engineInitializer){
try{const appRunner=await engineInitializer.initializeEngine({hostElement:document.getElementById('app')});await appRunner.runApp();}
catch(error){window.showRichangLoadError(error);}
}});
