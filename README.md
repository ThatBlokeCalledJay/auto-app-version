## AutoAppVersion.
Automatic application versioning that not only persits between builds, but also doesn't depend on the build number. Below is an example showing how this extension could be used.  
  
> Note: AutoAppVersion has been designed initially to work with Azure DevOps pipelines and DotNet Core projects.
  
### Set your version mask inside your app's project file (.csproj or .vbproj).  
  
`<Version>1.0.$</Version>`  
  
AAV will start to automatically increment the masked version number on each build.
  
> 1.0.0  
> 1.0.1  
> 1.0.2  
> 1.0.3  
  
### Increase your app's minor version.  
  
`<Version>1.1.$</Version>`  
  
AAV will detect the minor version has increased, and restart the masked incrementation from 0.  
  
> 1.1.0  
> 1.1.1  
> 1.1.2  

### Increase your app's major version.  
  
`<Version>2.0.$</Version>`  
  
AAV will detect the major version has increased, and restart the masked incrementation from 0.  

> 2.0.0  
> 2.0.1  
> 2.0.2  
> 2.0.3  
  
AAV writes the new version number directly into your current build's project file allowing any following tasks to utilize the project version like normal. The new version is also saved to a variable defined in your build definition.  
  
> **Note:** If you are unable to set a version mask inside your project file *(Ref: NETSDK1 Invalid NuGet version string)*, you can use the `Version Mask Override` field to specify the mask in your build task. For more help [click here](https://github.com/ThatBlokeCalledJay/auto-app-version/wiki/Unable-to-Set-Version-Mask-in-Project-File).

### Extra stuff.
- You have options which can stop the build if AAV detects certain problems.  
- You can tell AAV to set your project's FileVersion and AssemblyVersion based on the build's generated version number.  
- You have the option to specify and set an environment variable with the latest version number which can be used by proceeding tasks in your build.
  
### Need help setting up?
Check out the [wiki](https://github.com/ThatBlokeCalledJay/auto-app-version/wiki/Getting-Started) on getting started.  