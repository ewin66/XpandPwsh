﻿using System;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Reactive.Linq;
using System.Reactive.Threading.Tasks;
using System.Threading.Tasks;
using Octokit;
using SmartFormat;

namespace UpdateGithubIssue{
    [CmdletBinding(SupportsShouldProcess = true)]
    [Cmdlet(VerbsData.Update, "GithubIssue",SupportsShouldProcess = true)]
    public class UpdateGithubIssue : AsyncCmdlet{
        [Parameter(Mandatory = true)]
        public string GitHubApp{ get; set; } 
        [Parameter(Mandatory = true)]
        public string Owner{ get; set; } 
        [Parameter(Mandatory = true)]
        public string Organization{ get; set; } 
        [Parameter(Mandatory = true)]
        public string Repository1{ get; set; } 
        [Parameter(Mandatory = true)]
        public string Repository2{ get; set; } 
        
        [Parameter(Mandatory = true)]
        public string Message{ get; set; } 
        [Parameter]
        public string Branch{ get; set; } 
        [Parameter(Mandatory = true)]
        public string Pass{ get; set; }

        public SwitchParameter WhatIf{ get; set; }

        protected override async Task ProcessRecordAsync(){
            var shouldProcess = ShouldProcess("Create issue comment");
            var linkCommits = LinkCommits(this,shouldProcess).Replay().RefCount();
            await linkCommits;
            foreach (var psObject in linkCommits.ToEnumerable()){
                WriteObject(psObject);
            } 
        }

        internal async Task Test(){
            ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;
            var version = "18.2.601.2";
            var installerBuildUri ="https://dev.azure.com/eXpandDevOps/eXpandFramework/_build/results?buildId=BuildId&view=results";
            string nugetServerUri="https://xpandnugetserver.azurewebsites.net/";
            var updateGithubIssueMock = new UpdateGithubIssue{
                GitHubApp = "eXpandFramework",
                Owner = "apobekiaris",
                Organization = "eXpandFramework",
                Repository1 = "eXpand",
                Repository2 = "lab",
                Pass = Environment.GetEnvironmentVariable("GithubPass", EnvironmentVariableTarget.User),
                Message = $"Installer lab build [{version}]({installerBuildUri}) includes commit {{Commits}} that relate to this task. Please test if it addresses the problem. If you use nuget add our [NugetServer]({nugetServerUri}) as a nuget package source in VS"
            };
            await LinkCommits(updateGithubIssueMock, false);
        }

        private static IObservable<PSObject> LinkCommits( UpdateGithubIssue cmdLet,bool shouldCreateComment){
            var appClient = OctokitEx.CreateClient(cmdLet.Owner, cmdLet.Pass, cmdLet.GitHubApp);
            var issueToNotify = appClient
                .LastMileStone(cmdLet.Organization, cmdLet.Repository1)
                .SelectMany(milestone => appClient
                    .CommitIssues(cmdLet.Organization, cmdLet.Repository1, cmdLet.Repository2, milestone.Title,cmdLet.Branch)
                    .SelectMany(tuple => {
                        var issues = tuple.commitIssues
                            .SelectMany(_ => _.issues.Select(issue => (commit: _.commit, issue: issue))).ToObservable()
                            .SelectMany(_ => appClient.Issue.Comment
                                .GetAllForIssue(tuple.repoTuple.repo1.Id, _.issue.Number)
                                .ToObservable()
                                .Where(list => list.All(comment => !comment.Body.Contains(_.commit.Sha)))
                                .Select(list => (repo1: tuple.repoTuple.repo1.Id, repo2: tuple.repoTuple.repo2.Id,commit: _.commit, issue: _.issue)));
                        return issues;
                    }))
                .Replay().RefCount();

            return issueToNotify
                .GroupBy(_ => (issue: _.issue, repo1: _.repo1))
                .SelectMany(_ => {
                    return _.TakeUntil(_.LastAsync()).ToArray()
                        .Select(tuples => tuples.Select(valueTuple => valueTuple.commit).ToArray())
                        .Select(hubCommits => (key: _.Key, commits: hubCommits));
                })
                .SelectMany(_ => {
                    var comment = GenerateComment(_,cmdLet);
                    var issue = _.key.issue;
                    var psObject = Observable.Return(new PSObject(new {
                        IssueNumber = issue.Number, Milestone = issue.Milestone?.Title,issue.Title,
                        Commits = string.Join(",", _.commits.Select(commit => commit.Commit.Message)), Comment = comment
                    }));
                    if (shouldCreateComment){
                        return appClient.Issue.Comment.Create(_.key.repo1, _.key.issue.Number, comment)
                            .ToObservable().Select(issueComment => psObject).Concat();
                    }

                    return psObject;
                })
                .DefaultIfEmpty();
        }

        private static string GenerateComment(((Issue issue, long repoId) key, GitHubCommit[] commits) _,
            UpdateGithubIssue cmdLet){
            var objects = new object[] {
                new{
                    Options = cmdLet,
                    Commits = string.Join(",",
                        _.commits.Select(commit =>
                            $@"[{commit.Commit.Message}](https://github.com/{cmdLet.Organization}/{cmdLet.Repository2}/commit/{commit.Sha})"))
                }
            };
            var comment = Smart.Format(cmdLet.Message, objects);
            return comment;
        }
    }
}