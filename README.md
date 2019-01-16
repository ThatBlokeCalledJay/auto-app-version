## AutoAppVersion
An Azure DevOps build and release task designed to automatically increment your app's version number.  
  
### Please note, this read me is a WIP and will be improved upon.
  
## TODO:

  - [ ] Clearer docs.
  - [x] Implement error handling and better user feedback.
  - [ ] Options to set FileVersion and AssemblyVersion.
  - [ ] Provide option to stop on certain warnings.
  
## This Is Currently Used With:
  - Azure DevOps Pipelines.
  - DotNet Core Projects written in C#.
  
## So what is this? Example...
Don't worry about incrementing you're app's version number everytime you commit/integrate and deploy small patch updates, there's going to be a lot of them. Let AutoAppVersion increment the patch version for you. When you are ready to release a new Major or Minor version, simply update those version segmants like normal in your csporj file, AutoAppVersion will set the patch segment back to 0 for you. This is really handy when your BuildPipeline automatically packs and pushes NuGet packages. No more "Package with same name and Version number already exists" because you forgot to update the version.  
  
## Quick Setup Guide: 
Follow these steps to get things rolling as quickly as possible. After that, have a play.
  
1. In your csproj file make sure you have a version element, if you're looking for this extension then you will most likely know exactly what that is already. If not, it should be defined something like this:  
  
```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>...</TargetFramework>
        <PackageId>...</PackageId>
        <Version>1.0.0</Version>
    </PropertyGroup>
    ...
</Project>
```
  
2. Tell AutoAppVersion which version segment you want to automate (major, minor, patch), in this case we'll automate the patch segment. replace the patch value (third value) with a $ symbol like so `<Version>1.0.$</Version>`.You have now created a mask.  
  
3. Add this extension from the MarketPlace, then add the task to your primary agent job. Make sure this task is before any other task that depends on the app's version information.  
  
---  
  
![Agent Job Task](https://github.com/ThatBlokeCalledJay/auto-app-version/blob/master/Resources/task.png?raw=true "Agent job task")
  
---  
  
4. Setup some variables.  
  * A `VersionVariable` to hold the the latest version number (Ideally, you should initiate this with your app's current version e.g '3.6.24'). This variable will be automatically updated by AutoAppVersion and used to provide a new version number on each build. In the screenshot below, I have called mine `AutoVersion`.  
  * A variable to hold your [DevOps Personal Access Token](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts). Why do you need a PAT? AutoAppVersion has to update your `VersionVariable` via the DevOps api. Your PAT is required for authentication.
  
  
---  
  
![Variables](https://github.com/ThatBlokeCalledJay/auto-app-version/blob/master/Resources/variables.png?raw=true "Variables")  
  
---  
  
  
5. Populate the task inputs:  
* select the target csproj. This will be the file where you just set your version mask.
* Set the name of the `VersionVariable` used to store the current version (in the screenshot above I used AutoVersion)  
* Provide your [DevOps personal access token](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=vsts). I have used a variable to hold this value (DevOpsPAT in the above screen shot)  
  
Note: The minimum permissions required for your Personal Access Token are **Build:** Read & Execute.  
  
---
  
![AutoAppVersion Task Inputs](https://github.com/ThatBlokeCalledJay/auto-app-version/blob/master/Resources/inputs.png?raw=true "AutoAppVersion task inputs")  
  
---
  
6. Commit your project changes, and let your pipeline do the rest.
  
## That's it!!!
  
### What exactly is going on?  
AutoAppVersion will read the selected csproj file, looking for the version element. Depending on the the version mask, and a version number saved from your previous build, a new version number will be generated. The new version number will be saved back into the build's csproj file. Additional pipeline tasks such as deploying and packing will now make use of the new, incremented version number inside the csproj file.  

AutoAppVersion will also update your build's `VersionVariable` via the Azure DevOps Api (this is why your DevOps PAT is requird, for authenticating the request). If you keep an eye on your `VersionVariable` you will see it automaticvally increment after each build or release. 
  
### Why would anyone need this?
I simply made this because I kept on forgetting to update my version number whenever I commited a change. Utilising Azure DevOps CD/CI pipelines, and in some cases automatically re-packing and pushing packages meant, that if (and when) I forgot to update the version number, the release pipeline would fail because "Package with same name and Version number already exists"

### Setting up in a little more detail. 
Set your version number in your project's csproj file. It is here where you will be defining your version mask. Typically if you are planning on packaging your project, you will already have a `<PropertyGroup>` element which defines certain package information. It's the `<Version>` element we care about.
  
```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        <TargetFramework>...</TargetFramework>
        <PackageId>...</PackageId>
        <Version>1.0.0</Version>
    </PropertyGroup>
    ...
</Project>
```
  
Decide which segment of your version number you want to automate. Though, you can automate the Major, Minor and Patch segments, it is suggested you only automate the patch segment. Replacing a segment's value with $ informs AutoAppVersion that this segment is to be automated.  
  
```xml
<Project Sdk="Microsoft.NET.Sdk">
    <PropertyGroup>
        ...
        ...
        <Version>1.0.$</Version>
    </PropertyGroup>
    ...
</Project>
```
  
### General automated behaviour
  
A masked segment can mutate in two ways. Standard incrementation, 1, 2, 3, 4 and reset. Reset sets the segment back to 0.
  
Incrementing higher priority segments will result in lower priority, masked segments being set back to 0.
  
Major (Highest Priority)  
Minor (Medium Priority)  
Patch (Lowest Priority)  
  
If we take the version mask example above `1.0.$`. The final version output will always start with `1.0.` and patch will be incremented. Lets say you've deployed, several times without manually updating your Major and Minor versions, and the current version number is `1.0.14`, incrementing either Major or Minor segments now will cause the patch value to return to 0.  
  
e.g from `<Version>1.0.$</Version>` to `<Version>1.1.$</Version>` the next output number will be `1.1.0`, `1.1.1`, `1.1.2` etc.  
  
the same will hapen if you increment the Major version:  
  
e.g from `<Version>1.1.$</Version>` to `<Version>2.1.$</Version>` the next output number will be `2.1.0`, `2.1.1`, `2.1.2` etc.  
  
Any version segment that is hardcoded is still your responsibility to maintain. In the examples above, if you had changed your minor version number from `<Version>1.0.$</Version>` to `<Version>1.1.$</Version>`, then you wanted to increase the major version to 2, it is your responsibility to reset the minor version e.g `<Version>2.0.$</Version>`. AutoAppVersion will acknowledge this change and set the patch value back to 0 on the next deployment.  
  
AutoAppVersion will now save the new version number so it knows where to increment from on the next build. This is done by api, a http request is made against the current pipeline definition and the specified `VersionVariable` is updated.
  
Finally, the newly calculated version number is saved back to the project file, ultimatly overwriting the mask. Don't be alarmend by this, these files are only for use during this particular build or release.  
  
### What happens if...
Here's what happens if you mask your version number any other way then outlined above:  
  
`<Version>2.$.0</Version>` = `2.0.0`, `2.1.0`, `2.2.0`, `2.3.0`  
`<Version>2.$.6</Version>` = `2.0.6`, `2.1.6`, `2.2.6`, `2.3.6`  
`<Version>$.0.0</Version>` = `0.0.0`, `1.0.0`, `2.0.0`, `3.0.0`  
`<Version>$.5.8</Version>` = `0.5.8`, `1.5.8`, `2.5.8`, `3.5.8`  
  
### Multi mask...
`<Version>$.5.$</Version>` = `0.5.0`, `1.5.0`, `2.5.0`, `3.5.0`  
`<Version>1.$.$</Version>` = `1.0.0`, `1.1.0`, `1.2.0`, `1.3.0`  
`<Version>$.$.$</Version>` = `0.0.0`, `1.0.0`, `2.0.0`, `3.0.0`  
  
Notice how second or third masked values are always 0, this is because a higher priority segment value has been increased, AutoAppVersion will always set lower priority, masked segments to 0 if it detects a higher priority segment's value has increased.  
  
  
## WIP Notes
Your csproj file may have multiple `<PropertyGroup>` elements. This isn't a problem, however AutoAppVersion will only check the first instance of a `<PropertyGroup>` element for the version element. Long story short, put your package info `<PropertyGroup>` element with the version element before any others.  
  
Currently version suffix isn't supported (the hyphen on the patch version) e.g. '10.6.9-rc'  
  
## Important Shout Out:
I just want to say thanks to [Maik van der Gaag](https://github.com/maikvandergaag/msft-extensions/tree/develop/azuredevops/versioncounter) your project (specifically the api request code) really helped me out.
