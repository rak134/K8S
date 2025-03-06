<%@ page contentType="text/html;charset=UTF-8" language="java" %>
<html>
<head>
    <title>Demo Project</title>
</head>
<body>
    <h1>Redirecting to Welcome Page...</h1>
    <script>
        window.location.href = "${pageContext.request.contextPath}/welcome";
    </script>
</body>
</html>