## AutoAppVersion

Automatic application versioning that not only persits between builds, but also doesn't depend on the build number. Below is an example showing how this extension could be used.  
  
> Note: AutoAppVersion has been designed to work with **Azure DevOps** pipelines and **DotNet Core** projects.

### Make sure your project file (.csproj or .vbproj) has a version element  

`<Version>1.0.0</Version>`  

### Set your Version Mask Override in AAV  

![vmo](https://thatblokecalledjay.blob.core.windows.net/public-images/aav/vmo.png)
  
AAV will start to automatically increment the masked version number on each build.
  
> 1.0.0  
> 1.0.1  
> 1.0.2  
> 1.0.3  
  
### Increase your app's minor version  
  
`<Version>1.1.0</Version>`  
  
AAV will detect the minor version has increased, and restart the masked incrementation from 0.  
  
> 1.1.0  
> 1.1.1  
> 1.1.2  

### Increase your app's major version  
  
`<Version>2.0.0</Version>`  
  
AAV will detect the major version has increased, and restart the masked incrementation from 0.  

> 2.0.0  
> 2.0.1  
> 2.0.2  
> 2.0.3  
  
AAV writes the new version number directly into your current build's project file allowing any following tasks to utilize the project version like normal. The new version is also saved to a variable defined in your build definition.  
  
### Extra stuff

- You have options which can stop the build if AAV detects certain problems.  
- You can tell AAV to set your project's FileVersion and AssemblyVersion based on the build's generated version number.  
- You have the option to specify and set an environment variable with the latest version number which can be used by proceeding tasks in your build.
  
### Need help setting up

Check out the [wiki](https://github.com/ThatBlokeCalledJay/auto-app-version/wiki/Getting-Started) on getting started.  

### Minimum supported environments

- [Minimum agent version](https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/agents?view=azure-devops): 2.123.0

#### All the version numbers

Check out the following scenario:

1. Increment your app's current version.
2. Apply new version number to FileVersion.
3. Apply new version number to AssemblyVersion.
4. Ensure .Net pack uses your new version number when generating new packages.
5. Make sure all new bugs that are sent to Bugsnag include the new version number.
6. Finally, notify Bugsnag of your latest release, and it's new version number.

If you find yourself in this scenario, [click here](https://thatblokecalledjay.com/blog/view/justanotherday/continuous-integration-and-version-number-madness-b95d40aaf761) to find out how my Azure DevOps extensions can be made to work together to automate this entire process.

#### On GitHub

- [ThatBlokeCalledJay](https://github.com/ThatBlokeCalledJay)
- [AutoAppVersion](https://github.com/ThatBlokeCalledJay/auto-app-version)  
- [SetJsonProperty](https://github.com/ThatBlokeCalledJay/set-json-property)  
  
#### On Visual Studio Marketplace

- [ThatBlokeCalledJay](https://marketplace.visualstudio.com/publishers/ThatBlokeCalledJay)
- [AutoAppVersion](https://marketplace.visualstudio.com/items?itemName=ThatBlokeCalledJay.thatblokecalledjay-autoappversion)  
- [SetJsonProperty](https://marketplace.visualstudio.com/items?itemName=ThatBlokeCalledJay.thatblokecalledjay-setjsonproperty)  
